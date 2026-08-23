package com.fightdeck.baseline.services

import android.content.Context
import java.io.File
import java.net.ServerSocket
import java.util.concurrent.Executors

object LocalAssetServer {
    const val PORT = 8765
    private val executor = Executors.newCachedThreadPool()
    private var running = false

    fun start(context: Context) {
        if (running) return
        // Requested paths already carry the "assets/" prefix, so the root is the dataset itself.
        val serverRoot = DatasetLocator.datasetRoot(context)
        running = true
        executor.execute {
            ServerSocket(PORT).use { server ->
                while (running) {
                    val socket = server.accept()
                    executor.execute {
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
                                val header = "HTTP/1.1 404 Not Found\r\nContent-Length: ${body.length}\r\n\r\n$body"
                                output.write(header.toByteArray())
                            }
                            output.flush()
                        }
                        socket.close()
                    }
                }
            }
        }
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
