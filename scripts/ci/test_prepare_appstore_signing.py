#!/usr/bin/env python3
"""Checks for the App Store Connect app-record helper. No network."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


def load_module():
    path = Path(__file__).with_name("prepare-appstore-signing.py")
    spec = importlib.util.spec_from_file_location("prepare_appstore_signing", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class AppRecordTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_module()

    def test_simple_create_body_matches_the_app(self) -> None:
        body = self.mod.app_create_request()
        attributes = body["data"]["attributes"]
        self.assertEqual(body["data"]["type"], "apps")
        self.assertEqual(attributes["bundleId"], "com.arnar111.codexresettracker")
        self.assertEqual(attributes["name"], "Codex Reset Tracker")
        self.assertEqual(attributes["primaryLocale"], "en-US")
        self.assertEqual(attributes["sku"], "codex-reset-tracker")
        self.assertEqual(attributes["platform"], "IOS")

    def test_versioned_create_body_sets_ios_and_name(self) -> None:
        body = self.mod.app_create_request_with_version()
        included = {item["id"]: item for item in body["included"]}
        self.assertEqual(included["${store-version-IOS}"]["attributes"]["platform"], "IOS")
        self.assertEqual(included["${store-version-IOS}"]["attributes"]["versionString"], "1.0.0")
        self.assertEqual(included["${new-appInfoLocalization-id}"]["attributes"]["name"], "Codex Reset Tracker")
        self.assertEqual(included["${new-appInfoLocalization-id}"]["attributes"]["locale"], "en-US")
        self.assertEqual(body["data"]["attributes"]["bundleId"], "com.arnar111.codexresettracker")

    def test_create_forbidden_is_recognized(self) -> None:
        payload = {
            "errors": [
                {
                    "status": "403",
                    "code": "FORBIDDEN_ERROR",
                    "title": "The given operation is not allowed",
                    "detail": "The resource 'apps' does not allow 'CREATE'. Allowed operations are: GET_COLLECTION, GET_INSTANCE, UPDATE",
                }
            ]
        }
        self.assertTrue(self.mod.is_create_forbidden(403, payload))
        message = self.mod.create_forbidden_message(payload)
        self.assertIn("com.arnar111.codexresettracker", message)
        self.assertIn("codex-reset-tracker", message)
        self.assertNotIn("BEGIN PRIVATE KEY", message)

    def test_agreement_still_fails_closed(self) -> None:
        payload = {
            "errors": [
                {
                    "status": "403",
                    "code": "FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED",
                    "title": "A required agreement is missing or has expired.",
                    "detail": "Accept the latest license agreement.",
                }
            ]
        }
        with self.assertRaises(SystemExit):
            self.mod.raise_for_agreement(403, payload)

    def test_shape_error_does_not_treat_a_taken_name_as_retryable(self) -> None:
        taken = {
            "errors": [
                {
                    "status": "409",
                    "code": "ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE",
                    "title": "The provided entity includes an attribute with a value that has already been used",
                    "detail": "The name has already been taken.",
                }
            ]
        }
        self.assertTrue(self.mod.app_record_conflict(409, taken))
        self.assertFalse(self.mod.request_shape_error(409, taken))

    def test_company_name_required(self) -> None:
        payload = {
            "errors": [
                {
                    "status": "409",
                    "code": "ENTITY_ERROR.ATTRIBUTE.REQUIRED",
                    "title": "The provided entity is missing a required attribute",
                    "detail": "You must provide a value for the attribute 'companyName'.",
                }
            ]
        }
        self.assertTrue(self.mod.company_name_required(409, payload))


if __name__ == "__main__":
    unittest.main()
