"""Interface Streamlit do protótipo teórico do pipeline de lesões bucais."""

from __future__ import annotations

import hashlib
from io import BytesIO
from typing import Iterable

import streamlit as st
from PIL import Image, UnidentifiedImageError

from src.pipeline import (
    BoundingBox,
    CancerRiskClass,
    ClinicalImage,
    ElementaryLesionClass,
    ImageQualityStatus,
    PipelineController,
    PipelineStep,
    PipelineTransitionError,
    UserDecision,
    build_stub_config,
    clamp_box_to_image,
)
from src.ui.image_cropper import image_cropper


st.set_page_config(
    page_title="Pipeline de Lesões Bucais — Protótipo",
    page_icon="🦷",
    layout="wide",
)


def reset_simulation() -> None:
    for key in (
        "controller",
        "uploaded_bytes",
        "corrected_bytes",
        "crop_rejected",
        "cnn_disagreed",
    ):
        st.session_state.pop(key, None)
    st.rerun()


def load_image(raw: bytes) -> Image.Image:
    image = Image.open(BytesIO(raw))
    image.load()
    return image


def render_crop_preview(raw: bytes, box: BoundingBox | None) -> None:
    image = load_image(raw)
    if box is None:
        st.image(image, caption="Imagem corrigida selecionada", width="stretch")
        return
    preview_box = clamp_box_to_image(
        (box.x_min, box.y_min, box.x_max, box.y_max),
        image.width,
        image.height,
    )
    st.image(
        image.crop(preview_box),
        caption="Prévia da região de interesse selecionada",
        width="stretch",
    )


def render_example_cards(classes: Iterable[ElementaryLesionClass]) -> None:
    for lesion_class in classes:
        with st.container(border=True):
            st.markdown(f"**{lesion_class.value}**")
            st.caption(
                "EXEMPLO SIMULADO — cartão gráfico sintético, sem imagem real de paciente."
            )


def sidebar_configuration():
    st.sidebar.header("Configuração da simulação")
    st.sidebar.caption(
        "Valores fixos para reproduzir os desvios do pipeline. "
        "Mudanças passam a valer em uma nova simulação."
    )
    detection_success = st.sidebar.checkbox("YOLO encontra a lesão", value=True)
    st.sidebar.subheader("Bounding box fictícia")
    first, second = st.sidebar.columns(2)
    x_min = first.number_input("x mínimo", min_value=0, value=40, step=1)
    y_min = second.number_input("y mínimo", min_value=0, value=30, step=1)
    x_max = first.number_input("x máximo", min_value=1, value=360, step=1)
    y_max = second.number_input("y máximo", min_value=1, value=270, step=1)
    detection_confidence = st.sidebar.slider(
        "Confiança fictícia da YOLO", 0.0, 1.0, 0.88, 0.01
    )
    focus_score = st.sidebar.slider(
        "Escore interno fictício de foco", 0.0, 1.0, 0.82, 0.01
    )
    focus_status = st.sidebar.selectbox(
        "Status interno do foco",
        list(ImageQualityStatus),
        format_func=lambda item: item.value,
    )
    cnn_class = st.sidebar.selectbox(
        "Classe fixa da CNN fantasma",
        list(ElementaryLesionClass),
        index=list(ElementaryLesionClass).index(ElementaryLesionClass.ULCER),
        format_func=lambda item: item.value,
    )
    cnn_confidence = st.sidebar.slider(
        "Confiança fictícia da CNN", 0.0, 1.0, 0.81, 0.01
    )
    final_risk = st.sidebar.selectbox(
        "Risco fixo do modelo multimodal",
        list(CancerRiskClass),
        index=list(CancerRiskClass).index(CancerRiskClass.MEDIUM),
        format_func=lambda item: item.value,
    )
    try:
        config = build_stub_config(
            detection_success=detection_success,
            detection_box=(int(x_min), int(y_min), int(x_max), int(y_max)),
            detection_confidence=detection_confidence,
            focus_score=focus_score,
            focus_status=focus_status,
            cnn_class=cnn_class,
            cnn_confidence=cnn_confidence,
            final_risk=final_risk,
        )
    except ValueError as error:
        st.sidebar.error(str(error))
        st.stop()
    if st.sidebar.button("Reiniciar simulação", use_container_width=True):
        reset_simulation()
    return config


def show_history(controller: PipelineController) -> None:
    with st.expander("Histórico do pipeline", expanded=False):
        summary = controller.build_summary()
        st.json(summary)
        st.download_button(
            "Baixar resumo JSON",
            data=controller.build_summary_json().encode("utf-8"),
            file_name=f"resumo_pipeline_{controller.state.session_id}.json",
            mime="application/json",
            use_container_width=True,
        )


for key, default in (
    ("controller", None),
    ("uploaded_bytes", None),
    ("corrected_bytes", None),
    ("crop_rejected", False),
    ("cnn_disagreed", False),
):
    if key not in st.session_state:
        st.session_state[key] = default

config = sidebar_configuration()

st.title("Pipeline para Detecção, Processamento e Classificação de Lesões Bucais")
st.write(
    "Protótipo funcional e teórico destinado ao **profissional da saúde**. "
    "Todos os módulos computacionais desta tela são blocos fantasmas configuráveis."
)
st.warning(
    "Esta ferramenta é somente apoio à análise inicial. Não fornece diagnóstico, "
    "não substitui avaliação profissional e não substitui exames complementares "
    "quando indicados."
)

controller: PipelineController | None = st.session_state.controller

uploaded = st.file_uploader(
    "Envie uma imagem clínica simulada",
    type=["png", "jpg", "jpeg", "webp"],
    disabled=controller is not None,
)
if uploaded is not None and controller is None:
    raw = uploaded.getvalue()
    try:
        load_image(raw)
    except (UnidentifiedImageError, OSError):
        st.error("O arquivo selecionado não pôde ser lido como imagem.")
        st.stop()
    controller = PipelineController(config)
    controller.start_session(
        name=uploaded.name,
        source="upload_streamlit",
        byte_size=len(raw),
        content_hash=hashlib.sha256(raw).hexdigest(),
    )
    st.session_state.controller = controller
    st.session_state.uploaded_bytes = raw
    st.rerun()

if controller is None:
    st.info("Envie uma imagem para iniciar o fluxo simulado.")
    st.stop()

state = controller.state
st.subheader(f"Etapa atual: {state.step.value}")

if st.session_state.uploaded_bytes:
    st.image(
        load_image(st.session_state.uploaded_bytes),
        caption="Imagem original mantida em memória nesta sessão",
        width="stretch",
    )

try:
    if state.step is PipelineStep.IMAGE_LOADED:
        if st.button("Executar YOLO fantasma", type="primary"):
            controller.run_detection()
            st.rerun()

    elif state.step is PipelineStep.DETECTION_FAILED:
        st.error(state.final_message)
        if st.button("Enviar outra imagem"):
            reset_simulation()

    elif state.step is PipelineStep.DETECTED:
        detection = state.detection_result
        st.markdown("### Recorte automático simulado")
        st.write(
            f"Classe única detectada: **{detection.detected_class}** · "
            f"confiança fictícia interna: `{detection.confidence:.2f}`"
        )
        render_crop_preview(st.session_state.uploaded_bytes, detection.bounding_box)
        first, second = st.columns(2)
        if first.button("Recorte adequado", use_container_width=True):
            controller.accept_automatic_crop()
            st.rerun()
        if second.button("Recorte inadequado", use_container_width=True):
            st.session_state.crop_rejected = True
            st.rerun()

        if st.session_state.crop_rejected:
            st.info(
                "A correção será registrada pelo sistema inteligente como candidata "
                "à avaliação/curadoria e não será incorporada automaticamente."
            )
            correction_mode = st.radio(
                "Como deseja corrigir o recorte?",
                ("Recortar diretamente na imagem", "Enviar imagem corrigida"),
            )
            if correction_mode == "Recortar diretamente na imagem":
                st.caption(
                    "Arraste os pontos dos cantos ou das bordas para ajustar o recorte. "
                    "Arraste o interior do retângulo para movê-lo. "
                    "A prévia é atualizada ao soltar."
                )
                manual_box = image_cropper(
                    load_image(st.session_state.uploaded_bytes),
                    detection.bounding_box,
                    key=f"manual_crop_{state.session_id}",
                )
                if manual_box is not None:
                    st.markdown("#### Prévia do recorte manual")
                    render_crop_preview(st.session_state.uploaded_bytes, manual_box)
                if st.button(
                    "Confirmar recorte manual", type="primary", disabled=manual_box is None
                ):
                    controller.submit_manual_crop(bounding_box=manual_box)
                    st.rerun()
            else:
                corrected_upload = st.file_uploader(
                    "Selecione a imagem corrigida",
                    type=["png", "jpg", "jpeg", "webp"],
                    key="corrected_upload",
                )
                if corrected_upload is not None:
                    corrected_raw = corrected_upload.getvalue()
                    load_image(corrected_raw)
                    st.image(
                        load_image(corrected_raw),
                        caption="Imagem corrigida selecionada",
                        width="stretch",
                    )
                    if st.button("Registrar imagem corrigida"):
                        corrected_metadata = ClinicalImage.create(
                            corrected_upload.name,
                            "upload_corrigido",
                            len(corrected_raw),
                            hashlib.sha256(corrected_raw).hexdigest(),
                        )
                        controller.submit_manual_crop(
                            corrected_image=corrected_metadata
                        )
                        st.session_state.corrected_bytes = corrected_raw
                        st.rerun()

    elif state.step is PipelineStep.CROP_VALIDATED:
        st.success(
            "Recorte validado."
            + (" A correção manual foi registrada." if state.manual_crop_used else "")
        )
        preview_raw = (
            st.session_state.corrected_bytes
            if state.active_crop.source == "corrected_upload"
            else st.session_state.uploaded_bytes
        )
        render_crop_preview(preview_raw, state.active_crop.bounding_box)
        if st.button("Executar processamento e avaliação de foco", type="primary"):
            controller.run_focus_evaluation()
            st.rerun()

    elif state.step is PipelineStep.FOCUS_EVALUATED:
        st.markdown("### Validação da qualidade visual")
        with st.expander("Detalhes internos da simulação"):
            st.write(f"Escore fictício de foco: `{state.focus_result.score:.2f}`")
            st.write(f"Status interno: **{state.focus_result.status.value}**")
            st.caption("Esse escore não é a saída final do sistema.")
        st.write("A imagem apresenta qualidade visual suficiente para continuar?")
        first, second = st.columns(2)
        if first.button("Sim, qualidade adequada", use_container_width=True):
            controller.validate_visual_quality(UserDecision.ACCEPT)
            st.rerun()
        if second.button("Não, solicitar nova imagem", use_container_width=True):
            controller.validate_visual_quality(UserDecision.REJECT)
            st.rerun()

    elif state.step is PipelineStep.QUALITY_REJECTED:
        st.error(state.final_message)
        if st.button("Reiniciar e enviar nova imagem", type="primary"):
            reset_simulation()

    elif state.step is PipelineStep.QUALITY_ACCEPTED:
        st.success("Qualidade visual aceita pelo profissional da saúde.")
        if st.button("Executar CNN fantasma", type="primary"):
            controller.run_cnn_classification()
            st.rerun()

    elif state.step is PipelineStep.CNN_CLASSIFIED:
        result = state.cnn_result
        st.markdown("### Classe de lesão elementar sugerida")
        st.info(
            f"A imagem apresenta similaridade visual simulada com: **{result.suggested_class.value}**."
        )
        for example in result.example_descriptions:
            with st.container(border=True):
                st.caption(example)
        st.write("Você concorda com a classe de lesão elementar sugerida?")
        first, second = st.columns(2)
        if first.button("Concordo", use_container_width=True):
            controller.record_classification_decision(UserDecision.ACCEPT)
            st.rerun()
        if second.button("Discordo", use_container_width=True):
            st.session_state.cnn_disagreed = True
            st.rerun()

        if st.session_state.cnn_disagreed:
            alternatives = [
                item
                for item in ElementaryLesionClass
                if item is not result.suggested_class
            ]
            st.warning(
                "A discordância, a imagem e a classe corrigida serão registradas "
                "pelo sistema inteligente para curadoria e possível retreinamento futuro."
            )
            st.markdown("#### Exemplos simulados das demais classes")
            render_example_cards(alternatives)
            corrected_class = st.selectbox(
                "Qual classe se parece mais com a lesão do paciente?",
                alternatives,
                format_func=lambda item: item.value,
            )
            if st.button("Confirmar classe corrigida"):
                controller.record_classification_decision(
                    UserDecision.REJECT, corrected_class=corrected_class
                )
                st.rerun()

    elif state.step is PipelineStep.CLASS_CONFIRMED:
        st.markdown(f"### Questionário de {state.final_class.value}")
        st.warning(
            "Questionário simulado; o conteúdo clínico real será definido "
            "futuramente por profissional especialista em estomatologia."
        )
        questions = controller.get_questionnaire()
        with st.form("questionnaire_form"):
            responses = {}
            for question in questions:
                responses[question.question_id] = st.selectbox(
                    question.prompt,
                    ("Selecione uma opção", *question.answer_options),
                    key=f"{state.session_id}_{question.question_id}",
                )
            submitted = st.form_submit_button(
                "Enviar respostas simuladas", type="primary"
            )
        if submitted:
            if "Selecione uma opção" in responses.values():
                st.error("Responda todas as perguntas simuladas antes de continuar.")
            else:
                controller.submit_questionnaire(responses)
                st.rerun()

    elif state.step is PipelineStep.QUESTIONNAIRE_ANSWERED:
        st.success("Questionário fantasma registrado.")
        if st.button("Executar modelo multimodal específico por classe", type="primary"):
            controller.run_multimodal()
            st.rerun()

    elif state.step is PipelineStep.COMPLETED:
        result = state.multimodal_result
        st.markdown("### Resultado final da simulação")
        st.success(f"**{result.risk.value}**")
        st.warning(result.message)
        st.caption(f"Modelo utilizado: {result.model_name}")

except (ValueError, PipelineTransitionError, UnidentifiedImageError, OSError) as error:
    st.error(str(error))

show_history(controller)
