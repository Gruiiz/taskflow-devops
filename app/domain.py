"""Domain model and in-memory repository for TaskFlow."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from threading import Lock


class TaskValidationError(ValueError):
    """Raised when task input does not satisfy the domain rules."""


@dataclass(frozen=True, slots=True)
class Task:
    """A task tracked by the API."""

    id: int
    title: str
    completed: bool = False

    def to_dict(self) -> dict[str, int | str | bool]:
        """Return a JSON-serializable representation."""

        return asdict(self)


class TaskStore:
    """Thread-safe in-memory task repository."""

    MAX_TITLE_LENGTH = 120

    def __init__(self) -> None:
        self._tasks: dict[int, Task] = {}
        self._next_id = 1
        self._lock = Lock()

    def create(self, title: object) -> Task:
        """Validate and persist a new task."""

        normalized_title = self._validate_title(title)
        with self._lock:
            task = Task(id=self._next_id, title=normalized_title)
            self._tasks[task.id] = task
            self._next_id += 1
            return task

    def list_all(self) -> list[Task]:
        """Return all tasks ordered by identifier."""

        with self._lock:
            return [self._tasks[task_id] for task_id in sorted(self._tasks)]

    def get(self, task_id: int) -> Task | None:
        """Return one task or ``None`` when it does not exist."""

        with self._lock:
            return self._tasks.get(task_id)

    def delete(self, task_id: int) -> bool:
        """Delete a task and report whether it existed."""

        with self._lock:
            return self._tasks.pop(task_id, None) is not None

    @classmethod
    def _validate_title(cls, title: object) -> str:
        if not isinstance(title, str):
            raise TaskValidationError("O campo 'title' deve ser uma string.")

        normalized = " ".join(title.split())
        if not normalized:
            raise TaskValidationError("O campo 'title' é obrigatório.")
        if len(normalized) > cls.MAX_TITLE_LENGTH:
            raise TaskValidationError(
                f"O campo 'title' deve ter no máximo {cls.MAX_TITLE_LENGTH} caracteres."
            )
        return normalized
