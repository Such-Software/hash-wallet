package com.suchsoftware.hashwallet;

import android.content.Context;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Runs the embedded Wownero node daemon (wownerod) as a child process on-device.
 *
 * The daemon binary ships in jniLibs as {@code libwownerod.so}; with
 * extractNativeLibs=true Android extracts it to nativeLibraryDir, which is one
 * of the few app-accessible paths that stays executable on modern Android
 * (the app's writable data dir is W^X / noexec since API 29). We exec it from
 * there — the same technique Tor-on-Android and Termux use.
 *
 * Blockchain data lives under the app-specific external files dir (no runtime
 * permission needed, and roomier than internal storage for a multi-GB chain).
 */
public final class EmbeddedNode {
    static final int RPC_PORT = 34568;   // wallet connects to 127.0.0.1:34568
    static final int P2P_PORT = 34567;

    private static Process process;
    private static Thread reader;
    private static final Deque<String> logTail = new ArrayDeque<>();
    private static volatile long height = 0;
    private static volatile long targetHeight = 0;
    private static volatile boolean synced = false;

    // Wownero's sync line is decorated: "…♡ synced ♡… 2701/869596 (0%, 866895 left)".
    // Match the "<height>/<target> (<pct>%" shape regardless of surrounding emoji.
    private static final Pattern SYNC_RE =
            Pattern.compile("(\\d+)\\s*/\\s*(\\d+)\\s*\\((\\d+)%");
    private static final Pattern HEIGHT_RE =
            Pattern.compile("Height:\\s*(\\d+)\\s*/\\s*(\\d+)");

    private EmbeddedNode() {}

    public static synchronized boolean isRunning() {
        return process != null && process.isAlive();
    }

    /** Start wownerod. No-op if already running. Returns true if (now) running. */
    public static synchronized boolean start(Context ctx, boolean pruned) {
        if (isRunning()) return true;

        final String bin = ctx.getApplicationInfo().nativeLibraryDir + "/libwownerod.so";
        if (!new File(bin).exists()) return false;

        final File dataDir = new File(ctx.getExternalFilesDir(null), "wownero-node");
        if (!dataDir.exists() && !dataDir.mkdirs()) return false;

        List<String> cmd = new ArrayList<>();
        cmd.add(bin);
        cmd.add("--data-dir");           cmd.add(dataDir.getAbsolutePath());
        cmd.add("--rpc-bind-ip");        cmd.add("127.0.0.1");
        cmd.add("--rpc-bind-port");      cmd.add(Integer.toString(RPC_PORT));
        cmd.add("--p2p-bind-port");      cmd.add(Integer.toString(P2P_PORT));
        cmd.add("--no-igd");             // no UPnP on a phone
        cmd.add("--hide-my-port");       // don't advertise an inbound port
        cmd.add("--max-concurrency");    cmd.add("2");   // cap CPU/thermal
        cmd.add("--db-sync-mode");       cmd.add("fast:async:250000000bytes");
        cmd.add("--log-level");          cmd.add("0");
        cmd.add("--non-interactive");
        if (pruned) cmd.add("--prune-blockchain");   // ~3.5GB vs ~11GB full

        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.redirectErrorStream(true);
            pb.directory(dataDir);
            synced = false; height = 0; targetHeight = 0;
            synchronized (logTail) { logTail.clear(); }
            process = pb.start();
            reader = new Thread(EmbeddedNode::pump, "wownerod-log");
            reader.setDaemon(true);
            reader.start();
            return true;
        } catch (Exception e) {
            appendLog("failed to start: " + e.getMessage());
            process = null;
            return false;
        }
    }

    public static synchronized void stop() {
        if (process != null) {
            process.destroy();   // SIGTERM; wownerod flushes LMDB and exits
            process = null;
        }
        synced = false;
    }

    /** Snapshot of node state for the Dart side. */
    public static long[] progress() {
        return new long[]{ isRunning() ? 1 : 0, height, targetHeight, synced ? 1 : 0 };
    }

    public static String logs() {
        StringBuilder sb = new StringBuilder();
        synchronized (logTail) {
            for (String l : logTail) sb.append(l).append('\n');
        }
        return sb.toString();
    }

    private static void pump() {
        try (BufferedReader br = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = br.readLine()) != null) {
                appendLog(line);
                Matcher m = SYNC_RE.matcher(line);
                if (!m.find()) m = HEIGHT_RE.matcher(line);
                if (m.find()) {
                    try {
                        height = Long.parseLong(m.group(1));
                        targetHeight = Long.parseLong(m.group(2));
                        synced = targetHeight > 0 && height >= targetHeight - 1;
                    } catch (NumberFormatException ignored) {}
                }
                if (line.contains("SYNCHRONIZED OK")) synced = true;
            }
        } catch (Exception ignored) {
            // stream closed on process exit
        }
    }

    private static void appendLog(String line) {
        synchronized (logTail) {
            logTail.addLast(line);
            while (logTail.size() > 200) logTail.removeFirst();
        }
    }
}
