"""Unit tests for the TaskFlow domain."""

import unittest

from app.domain import TaskStore, TaskValidationError


class TaskStoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.store = TaskStore()

    def test_create_normalizes_title_and_assigns_sequential_id(self) -> None:
        first = self.store.create("  Preparar   pipeline  ")
        second = self.store.create("Validar Terraform")

        self.assertEqual(first.id, 1)
        self.assertEqual(first.title, "Preparar pipeline")
        self.assertEqual(second.id, 2)
        self.assertFalse(first.completed)

    def test_list_get_and_delete(self) -> None:
        task = self.store.create("Executar testes")

        self.assertEqual(self.store.list_all(), [task])
        self.assertEqual(self.store.get(task.id), task)
        self.assertTrue(self.store.delete(task.id))
        self.assertIsNone(self.store.get(task.id))
        self.assertFalse(self.store.delete(task.id))

    def test_rejects_invalid_titles(self) -> None:
        invalid_titles = [None, 42, "   ", "x" * 121]

        for title in invalid_titles:
            with self.subTest(title=title), self.assertRaises(TaskValidationError):
                self.store.create(title)

    def test_task_serializes_to_dictionary(self) -> None:
        task = self.store.create("Documentar arquitetura")

        self.assertEqual(
            task.to_dict(),
            {"id": 1, "title": "Documentar arquitetura", "completed": False},
        )


if __name__ == "__main__":
    unittest.main()
