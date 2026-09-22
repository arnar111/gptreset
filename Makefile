.PHONY: test test-core test-backend

test: test-core test-backend

test-core:
	swift test

test-backend:
	node --test backend/test/*.test.js
