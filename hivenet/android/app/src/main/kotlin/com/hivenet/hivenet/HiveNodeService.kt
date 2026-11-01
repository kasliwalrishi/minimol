package com.hivenet.hivenet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.*
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.security.MessageDigest
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** A small dependency-free HTTP server. It owns the on-device replica files. */
class HiveNodeService : Service() {
    private val port = 8765
    @Volatile private var running = false
    private var server: ServerSocket? = null
    // Accepting a connection must happen once in the server thread.  The prior
    // implementation submitted accept() itself to an unbounded pool, creating
    // thousands of blocking threads and crashing the app with OOM.
    private val workers: ExecutorService = Executors.newFixedThreadPool(4)
    private var nodeId = ""
    private lateinit var root: File

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences("hivenet", MODE_PRIVATE)
        nodeId = intent?.getStringExtra("nodeId") ?: prefs.getString("nodeId", nodeId) ?: "unknown"
        prefs.edit().putString("nodeId", nodeId).apply()
        root = File(filesDir, "hivenet").also { it.mkdirs() }
        if (Build.VERSION.SDK_INT >= 26) {
            (getSystemService(NotificationManager::class.java)).createNotificationChannel(
                NotificationChannel("hivenet_node", "HiveNet node", NotificationManager.IMPORTANCE_LOW))
        }
        startForeground(41, notification())
        if (!running) {
            running = true
            Thread { serve() }.start()
        }
        return START_STICKY
    }

    private fun notification() = NotificationCompat.Builder(this, "hivenet_node")
        .setSmallIcon(android.R.drawable.stat_sys_upload)
        .setContentTitle("HiveNet node active")
        .setContentText("Accepting LAN replicas on port $port")
        .setOngoing(true).build()

    private fun serve() {
        try {
            server = ServerSocket(port, 16)
            while (running) {
                val socket = server?.accept() ?: break
                workers.execute { handle(socket) }
            }
        } catch (_: IOException) {
            // Expected when onDestroy closes the listening socket. A later
            // sticky-service restart will construct a fresh accept loop.
        }
    }

    private fun handle(socket: Socket) {
        socket.use { s ->
            try {
                s.soTimeout = 30000
                val input = BufferedInputStream(s.getInputStream())
                val output = BufferedOutputStream(s.getOutputStream())
                val request = readRequest(input) ?: return
                when {
                    request.method == "OPTIONS" -> corsPreflight(output)
                    request.method == "GET" && request.path == "/v1/info" -> info(output)
                    request.method == "GET" && request.path == "/v1/files" -> listFiles(output)
                    request.method == "GET" && request.path.startsWith("/v1/files/") && request.path.endsWith("/meta") -> meta(output, idFromPath(request.path))
                    request.method == "GET" && request.path.startsWith("/v1/files/") -> download(output, idFromPath(request.path))
                    request.method == "PUT" && request.path.startsWith("/v1/files/") -> put(input, output, request, idFromPath(request.path))
                    else -> response(output, 404, "application/json", "{\"error\":\"not found\"}".toByteArray())
                }
            } catch (_: Exception) { }
        }
    }

    private data class Request(val method: String, val path: String, val headers: Map<String, String>)
    private fun readRequest(input: InputStream): Request? {
        val first = line(input) ?: return null
        val parts = first.split(" ")
        if (parts.size < 2) return null
        val headers = mutableMapOf<String, String>()
        while (true) {
            val h = line(input) ?: return null
            if (h.isEmpty()) break
            val at = h.indexOf(':'); if (at > 0) headers[h.substring(0, at).lowercase()] = h.substring(at + 1).trim()
        }
        return Request(parts[0], parts[1].substringBefore('?'), headers)
    }
    private fun line(input: InputStream): String? {
        val out = ByteArrayOutputStream(); var b: Int
        while (true) { b = input.read(); if (b < 0) return if (out.size() == 0) null else out.toString("UTF-8"); if (b == 10) break; if (b != 13) out.write(b); if (out.size() > 16384) return null }
        return out.toString("UTF-8")
    }

    private fun put(input: InputStream, out: OutputStream, r: Request, id: String) {
        if (!id.matches(Regex("[a-f0-9]{64}"))) return response(out, 400, "application/json", "{\"error\":\"invalid id\"}".toByteArray())
        val length = r.headers["content-length"]?.toLongOrNull() ?: return response(out, 411, "application/json", ByteArray(0))
        if (length < 1 || length > 50L * 1024 * 1024) return response(out, 413, "application/json", ByteArray(0))
        val expected = r.headers["x-hivenet-sha256"] ?: return response(out, 400, "application/json", ByteArray(0))
        val dir = File(root, "files").also { it.mkdirs() }; val tmp = File(dir, "$id.part"); val digest = MessageDigest.getInstance("SHA-256")
        FileOutputStream(tmp).use { file ->
            var remaining = length; val buffer = ByteArray(32 * 1024)
            while (remaining > 0) { val count = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt()); if (count < 0) throw EOFException(); file.write(buffer, 0, count); digest.update(buffer, 0, count); remaining -= count }
            file.fd.sync()
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        if (actual != expected.lowercase()) { tmp.delete(); return response(out, 422, "application/json", "{\"error\":\"checksum mismatch\"}".toByteArray()) }
        val target = File(dir, "$id.jpg"); if (!tmp.renameTo(target)) { tmp.copyTo(target, true); tmp.delete() }
        val name = URLDecoder.decode(r.headers["x-hivenet-name"] ?: "image.jpg", "UTF-8")
        File(dir, "$id.json").writeText(JSONObject().put("id", id).put("name", name).put("mime", r.headers["x-hivenet-mime"] ?: "image/jpeg").put("sha256", actual).put("bytes", length).put("createdAt", System.currentTimeMillis()).toString())
        response(out, 201, "application/json", JSONObject().put("stored", true).put("id", id).put("sha256", actual).toString().toByteArray())
    }
    private fun info(out: OutputStream) = response(out, 200, "application/json", JSONObject().put("nodeId", nodeId).put("port", port).put("freeBytes", root.usableSpace).toString().toByteArray())
    private fun listFiles(out: OutputStream) {
        val a = JSONArray(); File(root, "files").listFiles { f -> f.extension == "json" }?.forEach { a.put(JSONObject(it.readText())) }; response(out, 200, "application/json", a.toString().toByteArray())
    }
    private fun meta(out: OutputStream, id: String) { val f = File(root, "files/$id.json"); if (!f.exists()) response(out, 404, "application/json", ByteArray(0)) else response(out, 200, "application/json", f.readBytes()) }
    private fun download(out: OutputStream, id: String) { val f = File(root, "files/$id.jpg"); if (!f.exists()) response(out, 404, "application/json", ByteArray(0)) else response(out, 200, "image/jpeg", f.readBytes()) }
    private fun idFromPath(path: String) = path.removePrefix("/v1/files/").removeSuffix("/meta")
    // Chrome's Local Network Access / Private Network Access preflight asks
    // for this explicit opt-in before a public page may contact a LAN peer.
    // Older browsers safely ignore the extra CORS response header.
    private fun corsPreflight(out: OutputStream) { out.write("HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, PUT, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, X-HiveNet-Sha256, X-HiveNet-Name, X-HiveNet-Mime\r\nAccess-Control-Allow-Private-Network: true\r\nAccess-Control-Max-Age: 600\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray()); out.flush() }
    private fun response(out: OutputStream, status: Int, type: String, body: ByteArray) { val text = if (status in 200..299) "OK" else "Error"; out.write("HTTP/1.1 $status $text\r\nContent-Type: $type\r\nContent-Length: ${body.size}\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Private-Network: true\r\nConnection: close\r\n\r\n".toByteArray()); out.write(body); out.flush() }
    override fun onDestroy() { running = false; server?.close(); workers.shutdownNow(); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}
