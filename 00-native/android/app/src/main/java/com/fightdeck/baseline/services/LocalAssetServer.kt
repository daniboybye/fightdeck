package com.fightdeck.baseline.services

import android.content.Context
import java.io.File
import java.net.ServerSocket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

object LocalAssetServer {
    @Volatile
    var port: Int = 0
        private set

    private val executor = Executors.newCachedThreadPool()

    @Volatile
    private var running = false

    fun start(context: Context) {
        if (running) return
        // Requested paths already carry the "assets/" prefix, so the root is the dataset itself.
        val serverRoot = DatasetLocator.datasetRoot(context)
        running = true
        val ready = CountDownLatch(1)
        executor.execute {
            try {
                ServerSocket(0).use { server ->
                    port = server.localPort
                    ready.countDown()
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
                                            Content-Type: image/jpeg
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
            } catch (_: Exception) {
                ready.countDown()
            }
        }
        ready.await(5, TimeUnit.SECONDS)
    }
}

object DatasetLocator {
    fun datasetRoot(context: Context): File {
        System.getProperty("fightdeck.dataset.root")?.let { return File(it) }
        listOf(
            File("/data/local/tmp/fightdeck/dataset"),
            File(context.filesDir, "dataset"),
            File(context.applicationInfo.dataDir).resolve("../../../fightdeck/dataset"),
            File(System.getProperty("user.dir") ?: ".", "../../dataset"),
        ).forEach { candidate ->
            if (candidate.resolve("events.json").exists()) return candidate
        }
        return File("/Users/daniel.urumov/DevelopmentTools/fightdeck/dataset")
    }
}
