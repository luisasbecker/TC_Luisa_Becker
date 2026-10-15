import unittest

from src.pipeline import (
    CancerRiskClass,
    PipelineController,
    StubConfig,
    UserDecision,
)


def complete(controller: PipelineController) -> None:
    controller.start_session("imagem.png", "upload", 50, "hash")
    controller.run_detection()
    controller.accept_automatic_crop()
    controller.run_focus_evaluation()
    controller.validate_visual_quality(UserDecision.ACCEPT)
    controller.run_cnn_classification()
    controller.record_classification_decision(UserDecision.ACCEPT)
    questions = controller.get_questionnaire()
    controller.submit_questionnaire(
        {question.question_id: "Resposta simulada" for question in questions}
    )
    controller.run_multimodal()


class OutputSafetyTests(unittest.TestCase):
    def test_summary_contains_every_required_flow_result(self):
        controller = PipelineController()
        complete(controller)
        summary = controller.build_summary()
        self.assertEqual(
            set(summary),
            {
                "sessao_id",
                "imagem_original",
                "resultado_yolo_fantasma",
                "recorte_manual",
                "avaliacao_foco",
                "classe_sugerida_cnn",
                "decisao_usuario_cnn",
                "classe_final_questionario",
                "respostas_questionario",
                "modelo_multimodal_utilizado",
                "risco_final",
                "mensagem_final",
                "eventos_sistema_inteligente",
                "indicacoes_retreinamento_futuro",
                "historico_pipeline",
            },
        )
        self.assertEqual(
            summary["imagem_original"]["nome"], "imagem.png"
        )
        self.assertEqual(
            summary["resultado_yolo_fantasma"]["classe_detectada"], "lesão"
        )
        self.assertEqual(len(summary["respostas_questionario"]), 3)

    def test_every_risk_has_medical_guidance_and_never_uses_percentage(self):
        for risk in CancerRiskClass:
            with self.subTest(risk=risk):
                controller = PipelineController(StubConfig(final_risk=risk))
                complete(controller)
                result = controller.state.multimodal_result
                serialized = controller.build_summary_json()
                self.assertIn(result.risk, set(CancerRiskClass))
                self.assertNotIn("%", result.risk.value)
                self.assertNotIn("%", result.message)
                self.assertNotIn("%", serialized)
                self.assertIn("avaliação médica adequada", result.message.lower())
                self.assertIn("ferramenta de apoio", result.message.lower())
                self.assertIn("não substitui", result.message.lower())
                self.assertIn("exames complementares", result.message.lower())

    def test_summary_does_not_contain_image_bytes_or_diagnostic_claims(self):
        controller = PipelineController()
        complete(controller)
        serialized = controller.build_summary_json().lower()
        self.assertNotIn("image_bytes", serialized)
        self.assertNotIn("data:image", serialized)
        self.assertNotIn("é câncer", serialized)
        self.assertNotIn("não é câncer", serialized)

    def test_rejected_quality_summary_has_no_multimodal_result(self):
        controller = PipelineController()
        controller.start_session("ruim.png", "upload", 5, "hash")
        controller.run_detection()
        controller.accept_automatic_crop()
        controller.run_focus_evaluation()
        controller.validate_visual_quality(UserDecision.REJECT)
        summary = controller.build_summary()
        self.assertIsNone(summary["modelo_multimodal_utilizado"])
        self.assertIsNone(summary["risco_final"])
        self.assertIn("nova imagem", summary["mensagem_final"].lower())


if __name__ == "__main__":
    unittest.main()
