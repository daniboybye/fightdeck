#!/usr/bin/env bash
# UniFFI 0.32 async foreign-trait glue uses non-Sendable C callbacks inside Task { }.
# Swift 6 rejects that; box the closures so the generated file still compiles strict.
set -euo pipefail
FILE="${1:?usage: patch-swift-bindings.sh path/to/fightcore.swift}"

python3 - "$FILE" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()

text = text.replace("let task = Task { @MainActor in", "let task = Task {")

shim = """
private struct UniffiSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
"""

if "struct UniffiSendableBox" not in text:
    needle = "#endif\n\nfileprivate extension RustBuffer"
    if needle not in text:
        sys.exit(f"patch-swift-bindings: could not find insertion point in {path}")
    text = text.replace(
        needle,
        "#endif\n" + shim + "\nfileprivate extension RustBuffer",
        1,
    )

old_async = """private func uniffiTraitInterfaceCallAsync<T>(
    makeCall: @escaping () async throws -> T,
    handleSuccess: @escaping (T) -> (),
    handleError: @escaping (Int8, RustBuffer) -> (),
    droppedCallback: UnsafeMutablePointer<UniffiForeignFutureDroppedCallbackStruct>
) {
    let task = Task {"""

new_async = """private func uniffiTraitInterfaceCallAsync<T>(
    makeCall: @escaping () async throws -> T,
    handleSuccess: @escaping (T) -> (),
    handleError: @escaping (Int8, RustBuffer) -> (),
    droppedCallback: UnsafeMutablePointer<UniffiForeignFutureDroppedCallbackStruct>
) {
    let makeCallBox = UniffiSendableBox(makeCall)
    let handleSuccessBox = UniffiSendableBox(handleSuccess)
    let handleErrorBox = UniffiSendableBox(handleError)
    let task = Task {"""

old_async_body = """        do {
            callResult = try await makeCall()
        } catch {
            handleError(CALL_UNEXPECTED_ERROR, FfiConverterString.lower(String(describing: error)))
            return
        }
        handleSuccess(callResult)"""

new_async_body = """        do {
            callResult = try await makeCallBox.value()
        } catch {
            handleErrorBox.value(CALL_UNEXPECTED_ERROR, FfiConverterString.lower(String(describing: error)))
            return
        }
        handleSuccessBox.value(callResult)"""

old_async_err = """private func uniffiTraitInterfaceCallAsyncWithError<T, E>(
    makeCall: @escaping () async throws -> T,
    handleSuccess: @escaping (T) -> (),
    handleError: @escaping (Int8, RustBuffer) -> (),
    lowerError: @escaping (E) -> RustBuffer,
    droppedCallback: UnsafeMutablePointer<UniffiForeignFutureDroppedCallbackStruct>
) {
    let task = Task {"""

new_async_err = """private func uniffiTraitInterfaceCallAsyncWithError<T, E>(
    makeCall: @escaping () async throws -> T,
    handleSuccess: @escaping (T) -> (),
    handleError: @escaping (Int8, RustBuffer) -> (),
    lowerError: @escaping (E) -> RustBuffer,
    droppedCallback: UnsafeMutablePointer<UniffiForeignFutureDroppedCallbackStruct>
) {
    let makeCallBox = UniffiSendableBox(makeCall)
    let handleSuccessBox = UniffiSendableBox(handleSuccess)
    let handleErrorBox = UniffiSendableBox(handleError)
    let lowerErrorBox = UniffiSendableBox(lowerError)
    let task = Task {"""

old_async_err_body = """        do {
            callResult = try await makeCall()
        } catch let error as E {
            handleError(CALL_ERROR, lowerError(error))
            return
        } catch {
            handleError(CALL_UNEXPECTED_ERROR, FfiConverterString.lower(String(describing: error)))
            return
        }
        handleSuccess(callResult)"""

new_async_err_body = """        do {
            callResult = try await makeCallBox.value()
        } catch let error as E {
            handleErrorBox.value(CALL_ERROR, lowerErrorBox.value(error))
            return
        } catch {
            handleErrorBox.value(CALL_UNEXPECTED_ERROR, FfiConverterString.lower(String(describing: error)))
            return
        }
        handleSuccessBox.value(callResult)"""

for old, new in (
    (old_async, new_async),
    (old_async_body, new_async_body),
    (old_async_err, new_async_err),
    (old_async_err_body, new_async_err_body),
):
    if old not in text:
        if "makeCallBox = UniffiSendableBox" in text:
            continue
        sys.exit(f"patch-swift-bindings: expected snippet missing in {path}")
    text = text.replace(old, new, 1)

path.write_text(text)
PY
