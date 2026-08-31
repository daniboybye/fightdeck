package com.fightdeck.baseline.services

import android.content.Context
import java.io.File
import java.io.IOException
import java.net.ServerSocket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

object LocalAssetServer {
    @Volatile
    var port: Int = 0
        private set

    private val executor = Executors.newCachedThreadPool()

    @Volatile
    private var running = false

    /**
     * Binds on a background thread but waits for the port before returning. Returning early is
     * what let bootstrap report success while every image URL still pointed at port 0, leaving
     * posters grey until something unrelated forced a redraw.
     */
    @Synchronized
    fun start(serverRoot: File): Int {
        // Synchronized rather than a `running` flag check: the flag is set before the bind
        // completes, so an overlapping Retry used to fall through and start a second server
        // whose port then replaced the one already handed out.
        if (running && port > 0) {
            return port
        }
        // Requested paths already carry the "assets/" prefix, so the root is the dataset itself.
        running = true
        val bound = CountDownLatch(1)
        val failure = AtomicReference<Exception?>(null)
        executor.execute {
            try {
                ServerSocket(0).use { server ->
                    port = server.localPort
                    bound.countDown()
                    while (running) {
                        val socket = server.accept()
                        executor.execute {
                            try {
                                socket.getInputStream().bufferedReader().readLine()?.let { line ->
                                    val path = line.split(" ").getOrNull(1)?.trimStart('/') ?: ""
                                    val file = File(serverRoot, path)
                                    val output = socket.getOutputStream()
                                    if (file.exists() && file.canonicalPath.startsWith(serverRoot.canonicalPath)) {
                                        val bytes = file.readBytes()
                                        val header = """
                                            HTTP/1.1 200 OK
                                            Content-Type: ${mimeType(file.extension)}
                                            Content-Length: ${bytes.size}
                                            Connection: close

                                        """.trimIndent().replace("\n", "\r\n") + "\r\n"
                                        output.write(header.toByteArray())
                                        output.write(bytes)
                                    } else {
                                        val body = "Not Found"
                                        val header =
                                            "HTTP/1.1 404 Not Found\r\nContent-Length: ${body.length}\r\n\r\n$body"
                                        output.write(header.toByteArray())
                                    }
                                    output.flush()
                                }
                            } finally {
                                socket.close()
                            }
                        }
                    }
                }
            } catch (error: Exception) {
                running = false
                failure.compareAndSet(null, error)
            } finally {
                bound.countDown()
            }
        }
        if (!bound.await(BIND_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            stop()
            throw IOException("Local asset server did not bind a port in time")
        }
        failure.get()?.let { error ->
            stop()
            throw error
        }
        return port
    }

    /**
     * Clearing the port matters as much as clearing the flag: image URLs are built from it, so a
     * failed start that left the old number behind pointed Coil at a socket nobody was listening on.
     */
    @Synchronized
    fun stop() {
        running = false
        port = 0
    }

    private fun mimeType(extension: String): String = when (extension.lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        else -> "application/octet-stream"
    }

    private const val BIND_TIMEOUT_SECONDS = 5L
}

object DatasetLocator {
    class NotFoundException : Exception(
        "Dataset not found. Push the repo dataset to /data/local/tmp/fightdeck/dataset and retry.",
    )

    fun datasetRoot(context: Context): File =
        findDatasetRoot(context) ?: throw NotFoundException()

    fun findDatasetRoot(context: Context): File? {
        System.getProperty("fightdeck.dataset.root")?.let { return File(it) }
        listOf(
            File("/data/local/tmp/fightdeck/dataset"),
            File(context.filesDir, "dataset"),
            File(context.applicationInfo.dataDir).resolve("../../../fightdeck/dataset"),
            File(System.getProperty("user.dir") ?: ".", "../../dataset"),
        ).forEach { candidate ->
            if (candidate.resolve("events.json").exists()) {
                return candidate
            }
        }
        return null
    }
}
