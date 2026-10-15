from .enums import ElementaryLesionClass
from .models import QuestionnaireQuestion


class QuestionnaireStub:
    """Fornece perguntas genéricas simuladas, específicas por classe."""

    def questions_for(
        self, lesion_class: ElementaryLesionClass
    ) -> tuple[QuestionnaireQuestion, ...]:
        label = lesion_class.value
        return (
            QuestionnaireQuestion(
                "tempo_evolucao",
                f"PERGUNTA SIMULADA — Há quanto tempo a alteração semelhante a {label} foi percebida?",
                (
                    "Menos de 2 semanas",
                    "Entre 2 e 4 semanas",
                    "Mais de 4 semanas",
                    "Não informado",
                ),
            ),
            QuestionnaireQuestion(
                "sintomas",
                f"PERGUNTA SIMULADA — Há sintomas associados à alteração semelhante a {label}?",
                ("Não", "Sim", "Não informado"),
            ),
            QuestionnaireQuestion(
                "mudanca_recente",
                f"PERGUNTA SIMULADA — Foi percebida mudança recente na alteração semelhante a {label}?",
                ("Não", "Sim", "Não informado"),
            ),
        )
