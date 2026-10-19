import pathlib
import sys
import tempfile
import unittest
from importlib.machinery import SourceFileLoader

SCRIPTS = pathlib.Path(__file__).resolve().parent.parent
extract = SourceFileLoader("extract", str(SCRIPTS / "extract-strings.py")).load_module()
check = SourceFileLoader("check", str(SCRIPTS / "check-localization.py")).load_module()


def sources(files):
    folder = tempfile.TemporaryDirectory()
    root = pathlib.Path(folder.name)
    for name, text in files.items():
        (root / name).write_text(text)
    return folder, root


class ExtractionTests(unittest.TestCase):
    def test_text_next_to_a_symbol_name_is_extracted(self):
        folder, root = sources({"A.swift": 'Button("Añadir franja horaria", systemImage: "plus.circle", action: add)\n'})
        with folder:
            found = extract.literals([root])
        self.assertIn("Añadir franja horaria", found)
        self.assertNotIn("plus.circle", found)

    def test_label_with_symbol_and_status_text_are_extracted(self):
        folder, root = sources({"A.swift": 'Label("Activo", systemImage: "checkmark.circle.fill")\n'})
        with folder:
            found = extract.literals([root])
        self.assertIn("Activo", found)

    def test_log_messages_and_technical_arguments_are_not_interface_text(self):
        folder, root = sources({"A.swift": (
            'logger.error("export failed: \\(error)")\n'
            'defaults.bool(forKey: "visualizer")\n'
            'let font = Font.custom("Share Tech Mono", size: 12)\n'
            'Self.legibilityLogger.error("saving measurement failed: \\(error)")\n'
            'throw DecodingError.dataCorruptedError(forKey: .rows, in: container, debugDescription: "empty measurement")\n'
        )})
        with folder:
            found = extract.literals([root])
        self.assertEqual(found, {})


class StringTitleTests(unittest.TestCase):
    def test_a_view_that_takes_its_title_as_string_is_reported(self):
        folder, root = sources({
            "Slider.swift": (
                "private struct LabeledSlider: View {\n"
                "    let title: String\n"
                "    init(_ title: String, value: Binding<Double>) { self.title = title }\n"
                "    var body: some View { LabeledContent(title) { EmptyView() } }\n"
                "}\n"
            ),
            "Editor.swift": 'LabeledSlider("Ancho", value: $width)\n',
        })
        with folder:
            problems = check.literal_titles_passed_as_string([root])
        self.assertEqual(len(problems), 1)
        self.assertIn("LabeledSlider", problems[0])
        self.assertIn("Ancho", problems[0])

    def test_a_view_whose_title_is_a_localized_key_is_fine(self):
        folder, root = sources({
            "Slider.swift": (
                "private struct LabeledSlider: View {\n"
                "    let title: LocalizedStringKey\n"
                "    init(_ title: LocalizedStringKey, value: Binding<Double>) { self.title = title }\n"
                "}\n"
            ),
            "Editor.swift": 'LabeledSlider("Ancho", value: $width)\n',
        })
        with folder:
            self.assertEqual(check.literal_titles_passed_as_string([root]), [])


if __name__ == "__main__":
    unittest.main()
