# Protótipo do Pipeline de Lesões Bucais - Plano de Implementação

> **Para trabalhadores agênticos:** SUB-SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendada) ou `superpowers:executing-plans` para implementar este plano tarefa por tarefa. Os passos usam caixas de seleção (`- [ ]`) para acompanhamento.

**Objetivo:** Construir uma aplicação Streamlit com núcleo Python testável que simula, de forma determinística, o pipeline completo de detecção, processamento, classificação de lesão elementar, questionário, análise multimodal por classe e registro de feedback descrito no TCC I.

**Arquitetura:** Um `PipelineController` independente de interface aplica as regras de transição sobre um `SessionState` composto por dataclasses. Stubs injetáveis simulam YOLO, foco, CNN, questionários e seis modelos multimodais; o Streamlit apenas traduz interações do profissional da saúde em chamadas ao controlador e mantém bytes da imagem exclusivamente na sessão da interface.

**Stack técnica:** Python 3.11+, biblioteca padrão (`dataclasses`, `enum`, `hashlib`, `json`, `unittest`, `uuid`), Streamlit 1.x e Pillow 10+.

**Especificação:** `docs/superpowers/specs/2026-08-11-pipeline-lesoes-bucais-design.md`

## Restrições globais

- `TCC_I__Luisa_Becker_v6.pdf` é a fonte principal; os artigos são apenas apoio contextual.
- Não alterar o relatório do TCC nem os artigos presentes no repositório.
- Não implementar IA real, inferência real, treinamento, retreinamento, TensorFlow, PyTorch, YOLO real ou OpenCV.
- Usar “sistema inteligente”, “profissional da saúde”, “classe de lesão elementar” e “modelo multimodal específico por classe”.
- A saída final deve ser somente risco baixo, médio ou alto de câncer, nunca porcentagem ou diagnóstico definitivo.
- Toda saída multimodal deve orientar avaliação médica adequada e declarar os limites da ferramenta.
- Nenhuma imagem será persistida automaticamente; bytes ficam somente no `st.session_state` e não entram no resumo JSON.
- Exemplos visuais serão cartões sintéticos explicitamente marcados como simulados, sem bases reais de pacientes.
- Configurações dos stubs serão determinísticas e não usarão aleatoriedade.
- Usar `unittest`; o núcleo e todos os testes obrigatórios devem rodar sem Streamlit instalado.

---

## Mapa de arquivos e responsabilidades

| Arquivo | Responsabilidade única |
|---|---|
| `src/__init__.py` | Marcar o pacote de código-fonte. |
| `src/pipeline/__init__.py` | Expor apenas a API pública do pipeline. |
| `src/pipeline/enums.py` | Definir classes de lesão, qualidade, decisões, risco, feedback e etapas. |
| `src/pipeline/models.py` | Definir os valores imutáveis que atravessam os módulos. |
| `src/pipeline/state.py` | Conservar o estado mutável completo de uma sessão. |
| `src/pipeline/yolo_stub.py` | Simular detecção e recorte automático. |
| `src/pipeline/focus_stub.py` | Simular processamento e avaliação interna de foco. |
| `src/pipeline/cnn_stub.py` | Simular a classificação da classe de lesão elementar. |
| `src/pipeline/questionnaire_stub.py` | Fornecer perguntas simuladas específicas por classe. |
| `src/pipeline/multimodal_stub.py` | Conter seis stubs separados e roteamento por classe. |
| `src/pipeline/intelligent_system.py` | Criar eventos de feedback e candidatura à curadoria/retreinamento. |
| `src/pipeline/pipeline_controller.py` | Validar transições, orquestrar módulos e gerar o resumo JSON. |
| `app.py` | Implementar o assistente Streamlit sem regras clínicas ou de fluxo duplicadas. |
| `tests/test_domain_models.py` | Testar enums, validações e serialização básica. |
| `tests/test_stubs.py` | Testar previsibilidade e separação dos blocos fantasmas. |
| `tests/test_pipeline_flow.py` | Testar fluxo principal e desvios obrigatórios ponta a ponta. |
| `tests/test_output_safety.py` | Testar classes de risco, mensagem médica e ausência de porcentagens. |
| `requirements.txt` | Declarar somente dependências da interface. |
| `.gitignore` | Ignorar ambientes, caches e arquivos locais gerados. |
| `README.md` | Documentar objetivo, limitações, instalação, uso e testes. |

---

### Tarefa 1: Modelo de domínio e estado de sessão

**Arquivos:**
- Criar: `src/__init__.py`
- Criar: `src/pipeline/__init__.py`
- Criar: `src/pipeline/enums.py`
- Criar: `src/pipeline/models.py`
- Criar: `src/pipeline/state.py`
- Criar: `tests/__init__.py`
- Criar: `tests/test_domain_models.py`

**Interfaces:**
- Consome: nenhuma interface de produção anterior.
- Produz: `ElementaryLesionClass`, `ImageQualityStatus`, `UserDecision`, `CancerRiskClass`, `FeedbackEventType`, `PipelineStep`, `BoundingBox`, `ClinicalImage`, `CroppedImage`, `DetectionResult`, `FocusResult`, `CNNResult`, `ClassificationDecision`, `QuestionnaireQuestion`, `QuestionnaireAnswers`, `MultimodalResult`, `FeedbackEvent`, `HistoryEvent`, `StubConfig`, `SessionState` e `PipelineTransitionError`.

- [ ] **Passo 1: Escrever testes falhos para enumerações e bounding box**

```python
# tests/test_domain_models.py
import unittest

from src.pipeline.enums import CancerRiskClass, ElementaryLesionClass
from src.pipeline.models import BoundingBox


class DomainModelTests(unittest.TestCase):
    def test_defines_exactly_six_elementary_lesion_classes(self):
        self.assertEqual(
            {item.value for item in ElementaryLesionClass},
            {
                "pápula/nódulo",
                "mácula/mancha",
                "vesícula/bolha",
                "erosão",
                "úlcera",
                "placa",
            },
        )

    def test_defines_only_three_non_percentage_risk_classes(self):
        self.assertEqual(
            {item.value for item in CancerRiskClass},
            {
                "risco baixo de câncer",
                "risco médio de câncer",
                "risco alto de câncer",
            },
        )
        self.assertNotIn("%", " ".join(item.value for item in CancerRiskClass))

    def test_bounding_box_rejects_inverted_coordinates(self):
        with self.assertRaisesRegex(ValueError, "coordenadas"):
            BoundingBox(x_min=50, y_min=20, x_max=10, y_max=80)
```

- [ ] **Passo 2: Executar os testes e confirmar a falha correta**

Executar: `python -m unittest tests.test_domain_models -v`

Esperado: erro de importação de `src.pipeline.enums` ou ausência das classes, pois o domínio ainda não existe.

- [ ] **Passo 3: Implementar as enumerações e a validação geométrica mínimas**

```python
# src/pipeline/enums.py
from enum import Enum


class ElementaryLesionClass(str, Enum):
    PAPULE_NODULE = "pápula/nódulo"
    MACULE_SPOT = "mácula/mancha"
    VESICLE_BULLA = "vesícula/bolha"
    EROSION = "erosão"
    ULCER = "úlcera"
    PLAQUE = "placa"


class ImageQualityStatus(str, Enum):
    ADEQUATE = "adequada"
    INADEQUATE = "inadequada"


class UserDecision(str, Enum):
    ACCEPT = "aceita/concorda"
    REJECT = "rejeita/discorda"


class CancerRiskClass(str, Enum):
    LOW = "risco baixo de câncer"
    MEDIUM = "risco médio de câncer"
    HIGH = "risco alto de câncer"


class FeedbackEventType(str, Enum):
    MANUAL_CROP = "recorte manual"
    CNN_DISAGREEMENT = "discordância da CNN"
    CORRECTED_CLASS = "classe corrigida"
    RETRAINING_CANDIDATE = "candidata a retreinamento futuro"
    FLOW_METADATA = "metadados do fluxo"


class PipelineStep(str, Enum):
    EMPTY = "sem imagem"
    IMAGE_LOADED = "imagem carregada"
    DETECTION_FAILED = "detecção não concluída"
    DETECTED = "recorte automático gerado"
    CROP_VALIDATED = "recorte validado"
    FOCUS_EVALUATED = "foco avaliado"
    QUALITY_REJECTED = "qualidade rejeitada; novo envio necessário"
    QUALITY_ACCEPTED = "qualidade aceita"
    CNN_CLASSIFIED = "classe de lesão elementar sugerida"
    CLASS_CONFIRMED = "classe final definida"
    QUESTIONNAIRE_ANSWERED = "questionário respondido"
    COMPLETED = "análise multimodal concluída"
```

```python
# src/pipeline/models.py (primeira parte)
from dataclasses import dataclass


@dataclass(frozen=True)
class BoundingBox:
    x_min: int
    y_min: int
    x_max: int
    y_max: int

    def __post_init__(self) -> None:
        if min(self.x_min, self.y_min) < 0:
            raise ValueError("As coordenadas não podem ser negativas.")
        if self.x_max <= self.x_min or self.y_max <= self.y_min:
            raise ValueError("As coordenadas finais devem superar as iniciais.")

    def as_dict(self) -> dict[str, int]:
        return {
            "x_min": self.x_min,
            "y_min": self.y_min,
            "x_max": self.x_max,
            "y_max": self.y_max,
        }
```

- [ ] **Passo 4: Executar os testes de enumerações e bounding box**

Executar: `python -m unittest tests.test_domain_models -v`

Esperado: 3 testes passando.

- [ ] **Passo 5: Acrescentar testes falhos para identidade, vínculo e configuração determinística**

```python
# tests/test_domain_models.py
from src.pipeline.enums import ImageQualityStatus, PipelineStep
from src.pipeline.models import ClinicalImage, CroppedImage, StubConfig
from src.pipeline.state import SessionState


def test_image_lineage_is_explicit(self):
    original = ClinicalImage.create("caso-simulado.png", "upload", 1234, "abc")
    crop = CroppedImage.create(
        original=original,
        name="caso-simulado_recorte.png",
        source="yolo_stub",
        bounding_box=BoundingBox(10, 10, 100, 100),
        manual=False,
    )
    self.assertEqual(crop.parent_image_id, original.image_id)
    self.assertFalse(crop.manual)


def test_session_starts_empty(self):
    state = SessionState()
    self.assertEqual(state.step, PipelineStep.EMPTY)
    self.assertEqual(state.history, [])
    self.assertEqual(state.feedback_events, [])


def test_stub_configuration_has_fixed_defaults(self):
    config = StubConfig()
    self.assertEqual(config.focus_status, ImageQualityStatus.ADEQUATE)
    self.assertEqual(config.detection_confidence, 0.88)
```

- [ ] **Passo 6: Executar os testes e confirmar falhas por tipos ausentes**

Executar: `python -m unittest tests.test_domain_models -v`

Esperado: falha de importação ou atributo ausente para `ClinicalImage`, `SessionState` e `StubConfig`.

- [ ] **Passo 7: Implementar os valores de domínio e o estado completo**

Em `models.py`, implementar as dataclasses imutáveis com estas assinaturas exatas:

```python
@dataclass(frozen=True)
class ClinicalImage:
    image_id: str
    name: str
    source: str
    byte_size: int
    content_hash: str

    @classmethod
    def create(cls, name: str, source: str, byte_size: int, content_hash: str) -> "ClinicalImage":
        if not name.strip() or not source.strip() or not content_hash.strip():
            raise ValueError("Nome, origem e hash da imagem são obrigatórios.")
        if byte_size < 0:
            raise ValueError("O tamanho da imagem não pode ser negativo.")
        return cls(str(uuid4()), name, source, byte_size, content_hash)


@dataclass(frozen=True)
class CroppedImage:
    image_id: str
    name: str
    source: str
    parent_image_id: str
    bounding_box: BoundingBox | None
    manual: bool

    @classmethod
    def create(
        cls,
        original: ClinicalImage,
        name: str,
        source: str,
        bounding_box: BoundingBox | None,
        manual: bool,
    ) -> "CroppedImage":
        if not name.strip() or not source.strip():
            raise ValueError("Nome e origem do recorte são obrigatórios.")
        return cls(
            image_id=str(uuid4()),
            name=name,
            source=source,
            parent_image_id=original.image_id,
            bounding_box=bounding_box,
            manual=manual,
        )


@dataclass(frozen=True)
class DetectionResult:
    success: bool
    detected_class: str
    bounding_box: BoundingBox | None
    confidence: float | None
    cropped_image: CroppedImage | None
    message: str


@dataclass(frozen=True)
class FocusResult:
    image_id: str
    score: float
    status: ImageQualityStatus
    message: str


@dataclass(frozen=True)
class CNNResult:
    image_id: str
    suggested_class: ElementaryLesionClass
    confidence: float
    example_descriptions: tuple[str, ...]


@dataclass(frozen=True)
class ClassificationDecision:
    decision: UserDecision
    suggested_class: ElementaryLesionClass
    corrected_class: ElementaryLesionClass | None = None


@dataclass(frozen=True)
class QuestionnaireQuestion:
    question_id: str
    prompt: str
    answer_options: tuple[str, ...]


@dataclass(frozen=True)
class QuestionnaireAnswers:
    lesion_class: ElementaryLesionClass
    responses: dict[str, str]


@dataclass(frozen=True)
class MultimodalResult:
    lesion_class: ElementaryLesionClass
    model_name: str
    risk: CancerRiskClass
    message: str


@dataclass(frozen=True)
class FeedbackEvent:
    event_type: FeedbackEventType
    image_id: str
    details: dict[str, object]
    requires_curator_review: bool
    retraining_candidate: bool


@dataclass(frozen=True)
class HistoryEvent:
    step: PipelineStep
    message: str
    details: dict[str, object]


@dataclass(frozen=True)
class StubConfig:
    detection_success: bool = True
    detection_box: BoundingBox = BoundingBox(40, 30, 360, 270)
    detection_confidence: float = 0.88
    focus_score: float = 0.82
    focus_status: ImageQualityStatus = ImageQualityStatus.ADEQUATE
    cnn_class: ElementaryLesionClass = ElementaryLesionClass.ULCER
    cnn_confidence: float = 0.81
    final_risk: CancerRiskClass = CancerRiskClass.MEDIUM
```

Os métodos `create` usam `uuid.uuid4()` para identidade, não para decidir resultados. Validar `name`, `byte_size >= 0`, hash não vazio e probabilidades/escore dentro de `[0, 1]`.

Em `state.py`, implementar:

```python
class PipelineTransitionError(RuntimeError):
    """Indica tentativa de executar uma etapa fora da ordem do pipeline."""


@dataclass
class SessionState:
    session_id: str = field(default_factory=lambda: str(uuid4()))
    step: PipelineStep = PipelineStep.EMPTY
    original_image: ClinicalImage | None = None
    detection_result: DetectionResult | None = None
    active_crop: CroppedImage | None = None
    manual_crop_used: bool = False
    focus_result: FocusResult | None = None
    visual_quality_decision: UserDecision | None = None
    cnn_result: CNNResult | None = None
    classification_decision: ClassificationDecision | None = None
    final_class: ElementaryLesionClass | None = None
    questionnaire_answers: QuestionnaireAnswers | None = None
    multimodal_result: MultimodalResult | None = None
    feedback_events: list[FeedbackEvent] = field(default_factory=list)
    history: list[HistoryEvent] = field(default_factory=list)
    final_message: str | None = None
```

- [ ] **Passo 8: Exportar a API pública e executar os testes**

Em `src/pipeline/__init__.py`, reexportar os enums, dataclasses, `SessionState` e `PipelineTransitionError` sem importar Streamlit.

Executar: `python -m unittest tests.test_domain_models -v`

Esperado: 6 testes passando.

- [ ] **Passo 9: Commitar o domínio**

```powershell
git add src/__init__.py src/pipeline/__init__.py src/pipeline/enums.py src/pipeline/models.py src/pipeline/state.py tests/__init__.py tests/test_domain_models.py
git commit -m "feat: define oral lesion pipeline domain"
```

---

### Tarefa 2: Stubs previsíveis e sistema inteligente

**Arquivos:**
- Criar: `src/pipeline/yolo_stub.py`
- Criar: `src/pipeline/focus_stub.py`
- Criar: `src/pipeline/cnn_stub.py`
- Criar: `src/pipeline/questionnaire_stub.py`
- Criar: `src/pipeline/multimodal_stub.py`
- Criar: `src/pipeline/intelligent_system.py`
- Criar: `tests/test_stubs.py`
- Modificar: `src/pipeline/__init__.py`

**Interfaces:**
- Consome: dataclasses e enums da Tarefa 1.
- Produz: `YoloDetectionStub.detect(image)`, `FocusEvaluationStub.evaluate(image)`, `CNNClassificationStub.classify(image)`, `QuestionnaireStub.questions_for(lesion_class)`, seis classes multimodais com `analyze(image, lesion_class, answers)`, `build_multimodal_registry(config)` e métodos de registro de `IntelligentSystemStub`.

- [ ] **Passo 1: Escrever testes falhos para YOLO, foco e CNN**

```python
# tests/test_stubs.py
import unittest

from src.pipeline import ClinicalImage, ElementaryLesionClass, StubConfig
from src.pipeline.cnn_stub import CNNClassificationStub
from src.pipeline.focus_stub import FocusEvaluationStub
from src.pipeline.yolo_stub import YoloDetectionStub


class DeterministicStubTests(unittest.TestCase):
    def setUp(self):
        self.config = StubConfig(cnn_class=ElementaryLesionClass.PLAQUE)
        self.image = ClinicalImage.create("simulada.png", "upload", 100, "hash")

    def test_yolo_returns_configured_box_and_linked_crop(self):
        result = YoloDetectionStub(self.config).detect(self.image)
        self.assertTrue(result.success)
        self.assertEqual(result.bounding_box, self.config.detection_box)
        self.assertEqual(result.detected_class, "lesão")
        self.assertEqual(result.cropped_image.parent_image_id, self.image.image_id)

    def test_focus_returns_configured_internal_values(self):
        crop = YoloDetectionStub(self.config).detect(self.image).cropped_image
        result = FocusEvaluationStub(self.config).evaluate(crop)
        self.assertEqual(result.score, self.config.focus_score)
        self.assertEqual(result.status, self.config.focus_status)

    def test_cnn_returns_fixed_class_and_synthetic_examples(self):
        crop = YoloDetectionStub(self.config).detect(self.image).cropped_image
        result = CNNClassificationStub(self.config).classify(crop)
        self.assertEqual(result.suggested_class, ElementaryLesionClass.PLAQUE)
        self.assertGreaterEqual(len(result.example_descriptions), 2)
        self.assertTrue(all("SIMULADO" in item for item in result.example_descriptions))
```

- [ ] **Passo 2: Executar e confirmar falhas por módulos ausentes**

Executar: `python -m unittest tests.test_stubs.DeterministicStubTests -v`

Esperado: erro de importação dos stubs.

- [ ] **Passo 3: Implementar YOLO, foco e CNN com configuração fixa**

Implementar exatamente estas construções:

```python
class YoloDetectionStub:
    def __init__(self, config: StubConfig) -> None:
        self.config = config

    def detect(self, image: ClinicalImage) -> DetectionResult:
        if not self.config.detection_success:
            return DetectionResult(False, "lesão", None, None, None, "Detecção fantasma não concluída.")
        crop = CroppedImage.create(
            original=image,
            name=f"{image.name}_recorte_automatico",
            source="yolo_stub",
            bounding_box=self.config.detection_box,
            manual=False,
        )
        return DetectionResult(
            True,
            "lesão",
            self.config.detection_box,
            self.config.detection_confidence,
            crop,
            "YOLO fantasma localizou uma região de interesse simulada.",
        )
```

```python
class FocusEvaluationStub:
    def __init__(self, config: StubConfig) -> None:
        self.config = config

    def evaluate(self, image: CroppedImage) -> FocusResult:
        return FocusResult(
            image.image_id,
            self.config.focus_score,
            self.config.focus_status,
            "Avaliação de foco fantasma concluída; o escore é apenas controle interno.",
        )
```

```python
EXAMPLES_BY_CLASS: dict[ElementaryLesionClass, tuple[str, ...]] = {
    lesion_class: (
        f"EXEMPLO SIMULADO A — cartão sintético de {lesion_class.value}",
        f"EXEMPLO SIMULADO B — cartão sintético de {lesion_class.value}",
    )
    for lesion_class in ElementaryLesionClass
}


class CNNClassificationStub:
    def __init__(self, config: StubConfig) -> None:
        self.config = config

    def classify(self, image: CroppedImage) -> CNNResult:
        return CNNResult(
            image.image_id,
            self.config.cnn_class,
            self.config.cnn_confidence,
            EXAMPLES_BY_CLASS[self.config.cnn_class],
        )
```

- [ ] **Passo 4: Executar os três testes determinísticos**

Executar: `python -m unittest tests.test_stubs.DeterministicStubTests -v`

Esperado: 3 testes passando.

- [ ] **Passo 5: Escrever testes falhos para questionários e seis modelos multimodais**

```python
# tests/test_stubs.py
from src.pipeline import CancerRiskClass, QuestionnaireAnswers
from src.pipeline.multimodal_stub import (
    ErosionMultimodalStub,
    MaculeSpotMultimodalStub,
    PapuleNoduleMultimodalStub,
    PlaqueMultimodalStub,
    UlcerMultimodalStub,
    VesicleBullaMultimodalStub,
    build_multimodal_registry,
)
from src.pipeline.questionnaire_stub import QuestionnaireStub


def test_questionnaires_are_specific_and_explicitly_simulated(self):
    questionnaire = QuestionnaireStub()
    prompts_by_class = {
        lesion_class: tuple(q.prompt for q in questionnaire.questions_for(lesion_class))
        for lesion_class in ElementaryLesionClass
    }
    self.assertEqual(len(set(prompts_by_class.values())), 6)
    self.assertTrue(
        all("PERGUNTA SIMULADA" in prompt for prompts in prompts_by_class.values() for prompt in prompts)
    )


def test_registry_contains_one_concrete_stub_per_class(self):
    registry = build_multimodal_registry(StubConfig())
    self.assertEqual(
        {type(stub) for stub in registry.values()},
        {
            PapuleNoduleMultimodalStub,
            MaculeSpotMultimodalStub,
            VesicleBullaMultimodalStub,
            ErosionMultimodalStub,
            UlcerMultimodalStub,
            PlaqueMultimodalStub,
        },
    )


def test_each_multimodal_stub_returns_configured_enum_risk(self):
    registry = build_multimodal_registry(StubConfig(final_risk=CancerRiskClass.HIGH))
    crop = YoloDetectionStub(self.config).detect(self.image).cropped_image
    for lesion_class, stub in registry.items():
        answers = QuestionnaireAnswers(lesion_class, {"q1": "resposta simulada"})
        result = stub.analyze(crop, lesion_class, answers)
        self.assertIs(result.risk, CancerRiskClass.HIGH)
        self.assertEqual(result.lesion_class, lesion_class)
```

- [ ] **Passo 6: Executar e confirmar falhas por questionários/modelos ausentes**

Executar: `python -m unittest tests.test_stubs.DeterministicStubTests -v`

Esperado: erro de importação de `QuestionnaireStub` ou das seis classes multimodais.

- [ ] **Passo 7: Implementar perguntas distintas e os seis stubs separados**

Em `questionnaire_stub.py`, gerar três questões por classe com este conteúdo exato; mencionar `lesion_class.value` torna o conjunto específico da classe sem inventar critérios clínicos:

```python
class QuestionnaireStub:
    def questions_for(
        self, lesion_class: ElementaryLesionClass
    ) -> tuple[QuestionnaireQuestion, ...]:
        label = lesion_class.value
        return (
            QuestionnaireQuestion(
                "tempo_evolucao",
                f"PERGUNTA SIMULADA — Há quanto tempo a alteração semelhante a {label} foi percebida?",
                ("Menos de 2 semanas", "Entre 2 e 4 semanas", "Mais de 4 semanas", "Não informado"),
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
```

Em `multimodal_stub.py`, implementar uma base privada e seis subclasses concretas:

```python
MEDICAL_GUIDANCE = (
    "Este resultado indica {risk}. Busque avaliação médica adequada. "
    "O sistema é apenas uma ferramenta de apoio e não substitui avaliação profissional "
    "nem exames complementares quando indicados."
)


class _BaseMultimodalStub:
    lesion_class: ElementaryLesionClass

    def __init__(self, config: StubConfig) -> None:
        self.config = config

    def analyze(
        self,
        image: CroppedImage,
        lesion_class: ElementaryLesionClass,
        answers: QuestionnaireAnswers,
    ) -> MultimodalResult:
        if lesion_class is not self.lesion_class or answers.lesion_class is not lesion_class:
            raise ValueError("A classe deve corresponder ao modelo multimodal específico por classe.")
        if not answers.responses or any(not value.strip() for value in answers.responses.values()):
            raise ValueError("Todas as respostas simuladas devem ser preenchidas.")
        return MultimodalResult(
            lesion_class=lesion_class,
            model_name=type(self).__name__,
            risk=self.config.final_risk,
            message=MEDICAL_GUIDANCE.format(risk=self.config.final_risk.value),
        )
```

Cada subclasse define somente sua classe imutável. `build_multimodal_registry(config)` deve retornar um dicionário com as seis enumerações como chaves e instâncias dos tipos correspondentes.

- [ ] **Passo 8: Escrever teste falho e implementar o sistema inteligente**

Adicionar o teste:

```python
from src.pipeline.intelligent_system import IntelligentSystemStub


def test_intelligent_system_marks_feedback_for_human_curatorship(self):
    system = IntelligentSystemStub()
    crop = YoloDetectionStub(self.config).detect(self.image).cropped_image
    events = system.register_manual_crop(self.image, crop)
    self.assertEqual(len(events), 2)
    self.assertTrue(all(event.requires_curator_review for event in events))
    self.assertTrue(any(event.retraining_candidate for event in events))
```

Executar: `python -m unittest tests.test_stubs.DeterministicStubTests.test_intelligent_system_marks_feedback_for_human_curatorship -v`

Esperado: erro de importação de `IntelligentSystemStub`.

Implementar métodos puros que retornem tuplas de eventos:

```python
class IntelligentSystemStub:
    def register_manual_crop(
        self, original: ClinicalImage, crop: CroppedImage
    ) -> tuple[FeedbackEvent, FeedbackEvent]:
        common = {
            "imagem_original_id": original.image_id,
            "recorte_id": crop.image_id,
            "observacao": "Dado sujeito a curadoria; não incorporado automaticamente.",
        }
        return (
            FeedbackEvent(FeedbackEventType.MANUAL_CROP, crop.image_id, common, True, False),
            FeedbackEvent(
                FeedbackEventType.RETRAINING_CANDIDATE,
                crop.image_id,
                {**common, "modelo_futuro": "YOLO"},
                True,
                True,
            ),
        )

    def register_cnn_disagreement(
        self,
        image: CroppedImage,
        suggested: ElementaryLesionClass,
        corrected: ElementaryLesionClass,
    ) -> tuple[FeedbackEvent, FeedbackEvent, FeedbackEvent]:
        common = {
            "classe_sugerida": suggested.value,
            "classe_corrigida": corrected.value,
            "observacao": "Dado sujeito a curadoria; não incorporado automaticamente.",
        }
        return (
            FeedbackEvent(FeedbackEventType.CNN_DISAGREEMENT, image.image_id, common, True, False),
            FeedbackEvent(FeedbackEventType.CORRECTED_CLASS, image.image_id, common, True, False),
            FeedbackEvent(
                FeedbackEventType.RETRAINING_CANDIDATE,
                image.image_id,
                {**common, "modelo_futuro": "CNN"},
                True,
                True,
            ),
        )
```

`register_manual_crop` cria `MANUAL_CROP` e `RETRAINING_CANDIDATE`; `register_cnn_disagreement` cria `CNN_DISAGREEMENT`, `CORRECTED_CLASS` e `RETRAINING_CANDIDATE`. Todos exigem curadoria; somente os eventos candidatos têm `retraining_candidate=True`. Os detalhes devem conter nomes de classes, IDs e a frase “não incorporado automaticamente”.

- [ ] **Passo 9: Executar todos os testes dos stubs e exportar a API**

Executar: `python -m unittest tests.test_stubs -v`

Esperado: 7 testes passando.

Atualizar `src/pipeline/__init__.py` para exportar os seis modelos e construtores dos stubs, sem dependências de interface.

- [ ] **Passo 10: Commitar os blocos fantasmas**

```powershell
git add src/pipeline tests/test_stubs.py
git commit -m "feat: add deterministic pipeline stubs"
```

---

### Tarefa 3: Controlador e fluxo principal concordante

**Arquivos:**
- Criar: `src/pipeline/pipeline_controller.py`
- Criar: `tests/test_pipeline_flow.py`
- Modificar: `src/pipeline/__init__.py`

**Interfaces:**
- Consome: todos os tipos e stubs das Tarefas 1 e 2.
- Produz: `PipelineController` com métodos `start_session`, `run_detection`, `accept_automatic_crop`, `submit_manual_crop`, `run_focus_evaluation`, `validate_visual_quality`, `run_cnn_classification`, `record_classification_decision`, `get_questionnaire`, `submit_questionnaire`, `run_multimodal`, `build_summary` e `build_summary_json`.

- [ ] **Passo 1: Escrever o teste ponta a ponta do fluxo principal**

```python
# tests/test_pipeline_flow.py
import unittest

from src.pipeline import (
    ElementaryLesionClass,
    PipelineController,
    PipelineStep,
    StubConfig,
    UserDecision,
)


class PipelineFlowTests(unittest.TestCase):
    def test_complete_flow_with_automatic_crop_and_cnn_agreement(self):
        controller = PipelineController(
            StubConfig(cnn_class=ElementaryLesionClass.ULCER)
        )
        state = controller.start_session("imagem-simulada.png", "upload", 250, "hash-1")
        controller.run_detection()
        controller.accept_automatic_crop()
        controller.run_focus_evaluation()
        controller.validate_visual_quality(UserDecision.ACCEPT)
        controller.run_cnn_classification()
        controller.record_classification_decision(UserDecision.ACCEPT)
        questions = controller.get_questionnaire()
        controller.submit_questionnaire({q.question_id: "Resposta simulada" for q in questions})
        result = controller.run_multimodal()

        self.assertEqual(state.step, PipelineStep.COMPLETED)
        self.assertEqual(state.final_class, ElementaryLesionClass.ULCER)
        self.assertEqual(result.model_name, "UlcerMultimodalStub")
        self.assertFalse(state.manual_crop_used)
        self.assertIs(state.active_crop, state.detection_result.cropped_image)
```

- [ ] **Passo 2: Executar e confirmar falha por controlador ausente**

Executar: `python -m unittest tests.test_pipeline_flow.PipelineFlowTests.test_complete_flow_with_automatic_crop_and_cnn_agreement -v`

Esperado: erro de importação de `PipelineController`.

- [ ] **Passo 3: Implementar construção, início, detecção e recorte aceito**

```python
class PipelineController:
    def __init__(self, config: StubConfig | None = None) -> None:
        self.config = config or StubConfig()
        self.state = SessionState()
        self.yolo = YoloDetectionStub(self.config)
        self.focus = FocusEvaluationStub(self.config)
        self.cnn = CNNClassificationStub(self.config)
        self.questionnaire = QuestionnaireStub()
        self.multimodal_models = build_multimodal_registry(self.config)
        self.intelligent_system = IntelligentSystemStub()

    def _require(self, *steps: PipelineStep) -> None:
        if self.state.step not in steps:
            expected = ", ".join(step.value for step in steps)
            raise PipelineTransitionError(
                f"Etapa inválida: estado atual '{self.state.step.value}'; esperado: {expected}."
            )

    def _record(self, step: PipelineStep, message: str, **details: object) -> None:
        self.state.step = step
        self.state.history.append(HistoryEvent(step, message, details))
```

`start_session()` deve substituir o estado por uma nova `SessionState`, criar `ClinicalImage`, definir `IMAGE_LOADED` e registrar o primeiro histórico. `run_detection()` exige `IMAGE_LOADED`, salva o resultado e muda para `DETECTED` ou `DETECTION_FAILED`. `accept_automatic_crop()` exige `DETECTED`, copia o recorte automático para `active_crop`, mantém `manual_crop_used=False` e muda para `CROP_VALIDATED`.

- [ ] **Passo 4: Implementar foco, decisão visual e CNN**

`run_focus_evaluation()` exige `CROP_VALIDATED`, avalia `active_crop`, salva o `FocusResult` e muda para `FOCUS_EVALUATED`.

`validate_visual_quality(decision)` exige `FOCUS_EVALUATED` e sempre registra a decisão subjetiva. Para `REJECT`, define `final_message` como “A qualidade visual foi considerada inadequada. Envie uma nova imagem para reiniciar o pipeline.” e muda para `QUALITY_REJECTED`. Para `ACCEPT`, muda para `QUALITY_ACCEPTED`, mesmo que o status interno do stub seja inadequado, preservando a separação metodológica entre indicador interno e decisão subjetiva.

`run_cnn_classification()` exige `QUALITY_ACCEPTED`, classifica `active_crop`, salva `CNNResult` e muda para `CNN_CLASSIFIED`.

- [ ] **Passo 5: Implementar concordância, questionário e multimodal**

`record_classification_decision(UserDecision.ACCEPT)` exige `CNN_CLASSIFIED`, rejeita `corrected_class` preenchida, cria `ClassificationDecision`, usa `cnn_result.suggested_class` como `final_class` e muda para `CLASS_CONFIRMED`.

`get_questionnaire()` exige `CLASS_CONFIRMED` e retorna as perguntas da classe final.

`submit_questionnaire(responses)` exige `CLASS_CONFIRMED`, compara exatamente os IDs recebidos aos IDs exigidos, rejeita respostas vazias, salva `QuestionnaireAnswers` e muda para `QUESTIONNAIRE_ANSWERED`.

`run_multimodal()` exige `QUESTIONNAIRE_ANSWERED`, escolhe `self.multimodal_models[self.state.final_class]`, salva o resultado e a mensagem final e muda para `COMPLETED`.

- [ ] **Passo 6: Executar o teste do fluxo principal e corrigir somente incompatibilidades da API**

Executar: `python -m unittest tests.test_pipeline_flow.PipelineFlowTests.test_complete_flow_with_automatic_crop_and_cnn_agreement -v`

Esperado: 1 teste passando.

- [ ] **Passo 7: Escrever e passar teste de transições inválidas**

Adicionar:

```python
def test_rejects_out_of_order_transition_without_mutating_state(self):
    controller = PipelineController()
    controller.start_session("imagem.png", "upload", 10, "hash")
    history_before = list(controller.state.history)
    with self.assertRaisesRegex(Exception, "Etapa inválida"):
        controller.run_cnn_classification()
    self.assertEqual(controller.state.step, PipelineStep.IMAGE_LOADED)
    self.assertEqual(controller.state.history, history_before)
```

Executar: `python -m unittest tests.test_pipeline_flow -v`

Esperado antes da validação central: falha; após usar `_require()` no início de cada método: 2 testes passando.

- [ ] **Passo 8: Exportar o controlador e commitá-lo**

Atualizar `src/pipeline/__init__.py` para exportar `PipelineController`.

```powershell
git add src/pipeline/pipeline_controller.py src/pipeline/__init__.py tests/test_pipeline_flow.py
git commit -m "feat: orchestrate accepted oral lesion flow"
```

---

### Tarefa 4: Desvios de recorte, qualidade e discordância

**Arquivos:**
- Modificar: `src/pipeline/pipeline_controller.py`
- Modificar: `tests/test_pipeline_flow.py`

**Interfaces:**
- Consome: API pública do controlador da Tarefa 3.
- Produz: implementação validada de `submit_manual_crop(bounding_box=None, corrected_image=None)` e ramo de discordância de `record_classification_decision(decision, corrected_class=None)`.

- [ ] **Passo 1: Escrever teste falho para recorte manual por coordenadas**

```python
def test_rejected_automatic_crop_registers_manual_crop_and_continues(self):
    controller = PipelineController()
    original = controller.start_session("imagem.png", "upload", 20, "hash")
    controller.run_detection()
    manual = controller.submit_manual_crop(bounding_box=BoundingBox(5, 8, 200, 180))
    controller.run_focus_evaluation()

    self.assertTrue(controller.state.manual_crop_used)
    self.assertTrue(manual.manual)
    self.assertEqual(manual.parent_image_id, original.original_image.image_id)
    self.assertEqual(controller.state.step, PipelineStep.FOCUS_EVALUATED)
    self.assertTrue(
        any(event.event_type is FeedbackEventType.MANUAL_CROP for event in controller.state.feedback_events)
    )
    self.assertTrue(
        any(event.retraining_candidate for event in controller.state.feedback_events)
    )
```

- [ ] **Passo 2: Executar e confirmar falha por método ausente/incompleto**

Executar: `python -m unittest tests.test_pipeline_flow.PipelineFlowTests.test_rejected_automatic_crop_registers_manual_crop_and_continues -v`

Esperado: `AttributeError` ou transição não implementada.

- [ ] **Passo 3: Implementar as duas formas de correção manual**

Assinatura:

```python
def submit_manual_crop(
    self,
    bounding_box: BoundingBox | None = None,
    corrected_image: ClinicalImage | None = None,
) -> CroppedImage:
```

Regras:

- exigir etapa `DETECTED`;
- exigir exatamente uma das duas opções;
- para coordenadas, criar `CroppedImage` ligada à original, com origem `manual_coordinates`;
- para imagem corrigida, criar `CroppedImage` com `parent_image_id` da original, nome da imagem corrigida, origem `corrected_upload` e `bounding_box=None`;
- definir `manual_crop_used=True`, substituir `active_crop`, anexar eventos de `register_manual_crop()` e mudar para `CROP_VALIDATED`.

- [ ] **Passo 4: Escrever e passar teste para upload corrigido**

```python
def test_corrected_upload_preserves_original_lineage(self):
    controller = PipelineController()
    controller.start_session("original.png", "upload", 20, "hash-o")
    controller.run_detection()
    corrected = ClinicalImage.create("corrigida.png", "upload_corrigido", 18, "hash-c")
    crop = controller.submit_manual_crop(corrected_image=corrected)
    self.assertEqual(crop.name, "corrigida.png")
    self.assertEqual(crop.source, "corrected_upload")
    self.assertEqual(crop.parent_image_id, controller.state.original_image.image_id)
```

Executar: `python -m unittest tests.test_pipeline_flow -v`

Esperado: 4 testes passando.

- [ ] **Passo 5: Escrever teste falho para encerramento por qualidade inadequada**

```python
def test_inadequate_visual_quality_stops_before_cnn_and_requests_new_upload(self):
    controller = PipelineController(
        StubConfig(focus_status=ImageQualityStatus.INADEQUATE)
    )
    controller.start_session("desfocada.png", "upload", 15, "hash-d")
    controller.run_detection()
    controller.accept_automatic_crop()
    controller.run_focus_evaluation()
    controller.validate_visual_quality(UserDecision.REJECT)

    self.assertEqual(controller.state.step, PipelineStep.QUALITY_REJECTED)
    self.assertIsNone(controller.state.cnn_result)
    self.assertIsNone(controller.state.multimodal_result)
    self.assertIn("nova imagem", controller.state.final_message.lower())
    with self.assertRaisesRegex(Exception, "Etapa inválida"):
        controller.run_cnn_classification()
```

- [ ] **Passo 6: Executar e implementar o terminal de rejeição visual**

Executar antes: `python -m unittest tests.test_pipeline_flow.PipelineFlowTests.test_inadequate_visual_quality_stops_before_cnn_and_requests_new_upload -v`

Esperado: falha até `validate_visual_quality()` implementar a transição terminal.

Executar depois: mesmo comando.

Esperado: 1 teste passando.

- [ ] **Passo 7: Escrever teste falho para discordância e classe corrigida**

```python
def test_cnn_disagreement_uses_corrected_class_and_registers_feedback(self):
    controller = PipelineController(
        StubConfig(cnn_class=ElementaryLesionClass.ULCER)
    )
    controller.start_session("imagem.png", "upload", 12, "hash")
    controller.run_detection()
    controller.accept_automatic_crop()
    controller.run_focus_evaluation()
    controller.validate_visual_quality(UserDecision.ACCEPT)
    controller.run_cnn_classification()
    controller.record_classification_decision(
        UserDecision.REJECT,
        corrected_class=ElementaryLesionClass.PLAQUE,
    )

    self.assertEqual(controller.state.final_class, ElementaryLesionClass.PLAQUE)
    self.assertEqual(len(controller.state.feedback_events), 3)
    self.assertEqual(
        {event.event_type for event in controller.state.feedback_events},
        {
            FeedbackEventType.CNN_DISAGREEMENT,
            FeedbackEventType.CORRECTED_CLASS,
            FeedbackEventType.RETRAINING_CANDIDATE,
        },
    )
    questions = controller.get_questionnaire()
    controller.submit_questionnaire({q.question_id: "Resposta" for q in questions})
    result = controller.run_multimodal()
    self.assertEqual(result.model_name, "PlaqueMultimodalStub")
```

- [ ] **Passo 8: Implementar o ramo discordante com validações**

No ramo `REJECT` de `record_classification_decision`:

- exigir `corrected_class`;
- rejeitar uma classe corrigida igual à sugerida;
- criar `ClassificationDecision(REJECT, suggested, corrected)`;
- definir `final_class=corrected_class`;
- anexar os três eventos do sistema inteligente;
- mudar para `CLASS_CONFIRMED`.

No ramo `ACCEPT`, rejeitar qualquer `corrected_class` recebida.

- [ ] **Passo 9: Executar toda a suíte de fluxo e commitá-la**

Executar: `python -m unittest tests.test_pipeline_flow -v`

Esperado: 6 testes passando.

```powershell
git add src/pipeline/pipeline_controller.py tests/test_pipeline_flow.py
git commit -m "feat: support pipeline feedback branches"
```

---

### Tarefa 5: Resumo JSON e garantias da saída final

**Arquivos:**
- Criar: `tests/test_output_safety.py`
- Modificar: `src/pipeline/pipeline_controller.py`
- Modificar: `src/pipeline/models.py`

**Interfaces:**
- Consome: sessão concluída ou encerrada da Tarefa 4.
- Produz: `PipelineController.build_summary() -> dict[str, object]` e `PipelineController.build_summary_json() -> str`.

- [ ] **Passo 1: Escrever teste falho para resumo completo**

```python
# tests/test_output_safety.py
import json
import unittest

from src.pipeline import CancerRiskClass, PipelineController, StubConfig, UserDecision


def complete(controller: PipelineController) -> None:
    controller.start_session("imagem.png", "upload", 50, "hash")
    controller.run_detection()
    controller.accept_automatic_crop()
    controller.run_focus_evaluation()
    controller.validate_visual_quality(UserDecision.ACCEPT)
    controller.run_cnn_classification()
    controller.record_classification_decision(UserDecision.ACCEPT)
    questions = controller.get_questionnaire()
    controller.submit_questionnaire({q.question_id: "Resposta simulada" for q in questions})
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
```

- [ ] **Passo 2: Executar e confirmar falha por resumo ausente**

Executar: `python -m unittest tests.test_output_safety.OutputSafetyTests.test_summary_contains_every_required_flow_result -v`

Esperado: `AttributeError` para `build_summary`.

- [ ] **Passo 3: Implementar serialização explícita sem `asdict` indiscriminado**

`build_summary()` deve montar cada chave explicitamente para impedir vazamento futuro de bytes. Enumerações devem virar `.value`; bounding boxes usam `as_dict()`; eventos devem expor tipo, imagem, detalhes, necessidade de curadoria e candidatura. Para sessão interrompida, campos posteriores devem ser `None` ou dicionário vazio conforme o tipo.

`build_summary_json()` deve usar:

```python
def build_summary_json(self) -> str:
    return json.dumps(self.build_summary(), ensure_ascii=False, indent=2)
```

`indicacoes_retreinamento_futuro` deve ser uma lista derivada somente dos eventos com `retraining_candidate=True`, sempre incluindo a ressalva de curadoria e não incorporação automática.

- [ ] **Passo 4: Escrever testes falhos para todos os riscos, mensagem e ausência de porcentagem**

```python
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
```

- [ ] **Passo 5: Executar os testes de segurança e ajustar somente a serialização/cópia**

Executar: `python -m unittest tests.test_output_safety -v`

Esperado: 3 testes passando.

- [ ] **Passo 6: Testar resumo do encerramento antecipado**

```python
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
```

Executar: `python -m unittest tests.test_output_safety -v`

Esperado: 4 testes passando.

- [ ] **Passo 7: Executar toda a suíte do núcleo e commitá-la**

Executar: `python -m unittest discover -s tests -v`

Esperado: todos os testes das Tarefas 1–5 passando.

```powershell
git add src/pipeline/models.py src/pipeline/pipeline_controller.py tests/test_output_safety.py
git commit -m "feat: add safe pipeline session summary"
```

---

### Tarefa 6: Interface Streamlit em etapas

**Arquivos:**
- Criar: `app.py`
- Criar: `requirements.txt`
- Criar: `.gitignore`

**Interfaces:**
- Consome: apenas `PipelineController`, enums, `BoundingBox`, `ClinicalImage` e `StubConfig` da API pública.
- Produz: aplicação Streamlit com upload, configuração, decisões, questionário, resultado, histórico e download JSON.

- [ ] **Passo 1: Criar teste estrutural falho para impedir lógica proibida na interface**

Adicionar a `tests/test_output_safety.py`:

```python
from pathlib import Path


def test_interface_has_required_controls_and_no_ai_frameworks(self):
    source = Path("app.py").read_text(encoding="utf-8")
    for required in (
        "st.file_uploader",
        "Configuração da simulação",
        "PipelineController",
        "st.download_button",
        "Histórico do pipeline",
        "profissional da saúde",
    ):
        self.assertIn(required, source)
    lowered = source.lower()
    for forbidden in ("tensorflow", "torch", "opencv", "ultralytics"):
        self.assertNotIn(forbidden, lowered)
```

- [ ] **Passo 2: Executar e confirmar falha porque `app.py` não existe**

Executar: `python -m unittest tests.test_output_safety.OutputSafetyTests.test_interface_has_required_controls_and_no_ai_frameworks -v`

Esperado: `FileNotFoundError` para `app.py`.

- [ ] **Passo 3: Implementar configuração de página, aviso e sidebar determinística**

`app.py` deve:

- chamar `st.set_page_config(page_title="Pipeline de Lesões Bucais — Protótipo", layout="wide")`;
- explicar que todos os módulos são fantasmas;
- mostrar aviso permanente sobre apoio e avaliação profissional;
- criar na barra lateral seletores para sucesso YOLO, quatro coordenadas, status/escore de foco, classe fixa da CNN e risco fixo;
- construir um `StubConfig` a partir dos seletores antes de iniciar nova sessão;
- oferecer `Reiniciar simulação`, limpando controlador, bytes e escolhas da sessão.

Inicialização obrigatória:

```python
if "controller" not in st.session_state:
    st.session_state.controller = None
if "uploaded_bytes" not in st.session_state:
    st.session_state.uploaded_bytes = None
if "corrected_bytes" not in st.session_state:
    st.session_state.corrected_bytes = None
```

- [ ] **Passo 4: Implementar upload, hash local e visualização do recorte simulado**

No upload inicial:

```python
uploaded = st.file_uploader(
    "Envie uma imagem clínica simulada",
    type=["png", "jpg", "jpeg", "webp"],
)
if uploaded is not None and st.session_state.controller is None:
    raw = uploaded.getvalue()
    controller = PipelineController(config)
    controller.start_session(
        name=uploaded.name,
        source="upload_streamlit",
        byte_size=len(raw),
        content_hash=hashlib.sha256(raw).hexdigest(),
    )
    st.session_state.controller = controller
    st.session_state.uploaded_bytes = raw
```

Usar Pillow somente na interface para mostrar a imagem e, quando possível, `image.crop((x_min, y_min, x_max, y_max))`. Limitar coordenadas visualmente ao tamanho real antes da prévia, sem alterar o resultado fictício registrado pelo stub. Se o arquivo não puder ser aberto, mostrar erro e não iniciar o pipeline.

- [ ] **Passo 5: Implementar a etapa YOLO e as duas correções manuais**

Após `run_detection()`, mostrar caixa e confiança como valores simulados. Disponibilizar botões “Recorte adequado” e “Recorte inadequado”.

Quando inadequado, mostrar radio entre:

- “Ajustar coordenadas simuladas”: quatro `number_input` e chamada a `submit_manual_crop(bounding_box=BoundingBox(x_min, y_min, x_max, y_max))`;
- “Enviar imagem corrigida”: segundo `file_uploader`, criação por `ClinicalImage.create(corrected.name, "upload_corrigido", len(raw), hashlib.sha256(raw).hexdigest())` apenas com metadados e chamada a `submit_manual_crop(corrected_image=corrected_metadata)`.

Exibir claramente que o feedback irá ao sistema inteligente para avaliação/curadoria e não será incorporado automaticamente ao retreinamento.

- [ ] **Passo 6: Implementar foco, decisão visual, CNN e discordância**

- Mostrar escore de foco sob um `st.expander("Detalhes internos da simulação")`, evitando confundi-lo com o resultado final.
- Perguntar ao profissional da saúde se a qualidade visual é suficiente.
- Na rejeição, exibir a solicitação de nova imagem e botão de reinício; não renderizar etapas posteriores.
- Na aceitação, executar a CNN, mostrar “classe de lesão elementar sugerida” e cartões sintéticos.
- Perguntar concordância por radio/botões.
- Na discordância, mostrar cartões das cinco demais classes e um `selectbox` que exclua a classe sugerida antes de chamar o controlador.

- [ ] **Passo 7: Implementar questionário, multimodal e histórico**

- Renderizar cada `QuestionnaireQuestion` com `st.selectbox`, usando `question_id` como chave.
- Mostrar em destaque: “Questionário simulado; conteúdo clínico real será definido futuramente por profissional especialista em estomatologia.”
- Bloquear envio enquanto alguma resposta estiver vazia.
- Após `run_multimodal()`, exibir risco como texto, nunca métrica percentual, e mostrar integralmente a mensagem médica.
- Mostrar `controller.build_summary()` em `st.json` sob “Histórico do pipeline”.
- Criar `st.download_button` com `controller.build_summary_json().encode("utf-8")`, MIME `application/json` e nome `resumo_pipeline_<session_id>.json`.

- [ ] **Passo 8: Declarar dependências e ignorar artefatos locais**

```text
# requirements.txt
streamlit>=1.40,<2
Pillow>=10,<12
```

```text
# .gitignore
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/
.streamlit/secrets.toml
```

- [ ] **Passo 9: Executar verificações sem instalar a interface**

Executar:

```powershell
python -m unittest tests.test_output_safety.OutputSafetyTests.test_interface_has_required_controls_and_no_ai_frameworks -v
python -m py_compile app.py
python -m unittest discover -s tests -v
```

Esperado: teste estrutural passando, compilação sem saída/erro e suíte completa passando.

- [ ] **Passo 10: Commitar a interface**

```powershell
git add app.py requirements.txt .gitignore tests/test_output_safety.py
git commit -m "feat: add Streamlit pipeline walkthrough"
```

---

### Tarefa 7: Documentação, auditoria terminológica e verificação final

**Arquivos:**
- Criar: `README.md`
- Modificar: arquivos de produção e testes somente se uma verificação desta tarefa revelar uma falha.

**Interfaces:**
- Consome: protótipo completo das Tarefas 1–6.
- Produz: instruções reproduzíveis e evidência final de conformidade.

- [ ] **Passo 1: Escrever README completo**

Incluir estas seções e conteúdos concretos:

1. **Objetivo e estágio do TCC:** protótipo teórico para validar passagem de informação.
2. **Aviso clínico:** apoio, sem diagnóstico, com orientação médica em todos os riscos.
3. **Fluxo:** imagem → YOLO fantasma → validação/correção → foco → validação visual → CNN → concordância/correção → questionário → modelo multimodal específico por classe → risco.
4. **Arquitetura:** tabela de módulos e responsabilidades.
5. **Pré-requisitos:** Python 3.11 ou superior.
6. **Instalação:** criação de ambiente virtual e `python -m pip install -r requirements.txt`.
7. **Execução:** `python -m streamlit run app.py`.
8. **Configuração dos stubs:** como fixar YOLO, foco, classe e risco na sidebar.
9. **Cenários manuais:** os quatro fluxos principais com cliques esperados.
10. **Testes:** `python -m unittest discover -s tests -v` e lista dos sete critérios obrigatórios.
11. **Privacidade:** nenhuma persistência automática, sem bases reais e JSON sem bytes.
12. **Limitações e trabalho futuro:** questionários, modelos, curadoria e retreinamento ainda não implementados clinicamente.

- [ ] **Passo 2: Executar auditoria de termos proibidos e obrigatórios**

Executar:

```powershell
rg -n -i "agente especialista automatizado|especialista em odontologia|é câncer|não é câncer" app.py README.md src tests
rg -n "sistema inteligente|profissional da saúde|classe de lesão elementar|modelo multimodal específico por classe" app.py README.md src
```

Esperado: o primeiro comando sem ocorrências em textos da aplicação (a única ocorrência aceitável de frases diagnósticas é a asserção negativa do teste de segurança); o segundo comando deve encontrar os quatro termos obrigatórios em textos de produção/documentação.

- [ ] **Passo 3: Verificar ausência de frameworks/modelos reais**

Executar:

```powershell
rg -n -i "tensorflow|pytorch|torch|ultralytics|cv2|opencv|yolov[0-9]" app.py requirements.txt src
```

Esperado: nenhuma ocorrência.

- [ ] **Passo 4: Executar a suíte completa em modo detalhado**

Executar: `python -m unittest discover -s tests -v`

Esperado: todos os testes passando, incluindo:

- recorte automático aceito;
- recorte manual registrado;
- qualidade inadequada encerrando o fluxo;
- discordância e classe corrigida;
- três classes possíveis de risco;
- ausência de porcentagem;
- orientação médica em todos os riscos;
- seis modelos multimodais separados;
- resumo seguro e histórico completo.

- [ ] **Passo 5: Executar verificações de sintaxe e integridade do diff**

Executar:

```powershell
python -m compileall -q app.py src tests
git diff --check
git status --short
```

Esperado: compilação silenciosa, `git diff --check` sem saída e apenas `README.md`/eventuais correções desta tarefa pendentes. Os PDFs fornecidos devem continuar não rastreados e inalterados.

- [ ] **Passo 6: Fazer revisão manual do fluxo contra a especificação**

Conferir cada seção de `docs/superpowers/specs/2026-08-11-pipeline-lesoes-bucais-design.md` e registrar no handoff final:

- arquivo que atende a cada módulo;
- teste que comprova cada desvio obrigatório;
- confirmação de que não existe persistência automática;
- confirmação de que a saída final não é percentual nem diagnóstica;
- confirmação de que os seis modelos específicos existem.

- [ ] **Passo 7: Commitar documentação e eventuais correções finais**

```powershell
git add README.md app.py requirements.txt .gitignore src tests
git commit -m "docs: explain oral lesion pipeline prototype"
```

- [ ] **Passo 8: Verificar o estado final do repositório**

Executar:

```powershell
git log --oneline -7
git status --short
```

Esperado: commits pequenos correspondentes às tarefas; somente os PDFs-fonte permanecem não rastreados. Não adicionar nem modificar os PDFs.

---

## Pontos de validação com a autora

Durante a execução, interromper e solicitar confirmação somente se surgir uma decisão que mude o desenho aprovado. Em particular:

1. após o domínio e o fluxo principal, apresentar as transições implementadas;
2. após os desvios, apresentar os eventos enviados ao sistema inteligente;
3. antes de finalizar a interface, apresentar a sequência de telas/controles;
4. após os testes, apresentar a matriz cenário → evidência.

Correções técnicas internas que preservem assinaturas, terminologia e fluxo podem ser feitas sem interromper o ciclo TDD.
