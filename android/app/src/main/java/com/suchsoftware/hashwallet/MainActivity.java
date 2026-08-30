package com.suchsoftware.hashwallet;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.GeneratedPluginRegistrant;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.WindowManager;
import android.content.Intent;
import android.net.Uri;
import android.os.PowerManager;
import android.provider.Settings;

import java.security.SecureRandom;

public class MainActivity extends FlutterFragmentActivity {
    final String UTILS_CHANNEL = "com.cake_wallet/native_utils";
    final String NODE_CHANNEL = "cash.hashbags/embedded_node";
    boolean isAppSecure = false;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        MethodChannel utilsChannel =
                new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                        UTILS_CHANNEL);

        utilsChannel.setMethodCallHandler(this::handle);

        MethodChannel nodeChannel =
                new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                        NODE_CHANNEL);

        nodeChannel.setMethodCallHandler(this::handleNode);
    }

    private void handleNode(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        Handler handler = new Handler(Looper.getMainLooper());
        try {
            switch (call.method) {
                case "start": {
                    Boolean pruned = call.argument("pruned");
                    boolean ok = EmbeddedNode.start(getApplicationContext(), pruned == null || pruned);
                    handler.post(() -> result.success(ok));
                    break;
                }
                case "stop":
                    EmbeddedNode.stop();
                    handler.post(() -> result.success(null));
                    break;
                case "progress": {
                    long[] p = EmbeddedNode.progress();
                    java.util.HashMap<String, Object> m = new java.util.HashMap<>();
                    m.put("running", p[0] == 1);
                    m.put("height", p[1]);
                    m.put("targetHeight", p[2]);
                    m.put("synced", p[3] == 1);
                    handler.post(() -> result.success(m));
                    break;
                }
                case "rpcPort":
                    handler.post(() -> result.success(EmbeddedNode.RPC_PORT));
                    break;
                case "logs":
                    handler.post(() -> result.success(EmbeddedNode.logs()));
                    break;
                default:
                    handler.post(() -> result.notImplemented());
            }
        } catch (Exception e) {
            handler.post(() -> result.error("EMBEDDED_NODE_ERROR", e.getMessage(), null));
        }
    }

    private void handle(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        Handler handler = new Handler(Looper.getMainLooper());

        try {
            switch (call.method) {
                case "sec_random":
                    int count = call.argument("count");
                    SecureRandom random = new SecureRandom();
                    byte bytes[] = new byte[count];
                    random.nextBytes(bytes);
                    handler.post(() -> result.success(bytes));
                    break;
                case "setIsAppSecure":
                    isAppSecure = call.argument("isAppSecure");
                    if (isAppSecure) {
                        getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
                    } else {
                        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
                    }
                    break;
                case "disableBatteryOptimization":
                    disableBatteryOptimization();
                    handler.post(() -> result.success(null));
                    break;
                case "isBatteryOptimizationDisabled":
                    boolean isDisabled = isBatteryOptimizationDisabled();
                    handler.post(() -> result.success(isDisabled));
                    break;
                default:
                    handler.post(() -> result.notImplemented());
            }
        } catch (Exception e) {
            handler.post(() -> result.error("UNCAUGHT_ERROR", e.getMessage(), null));
        }
    }

    private void disableBatteryOptimization() {
        String packageName = getPackageName();
        PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            Intent intent = new Intent();
            intent.setAction(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + packageName));
            startActivity(intent);
        }
    }

    private boolean isBatteryOptimizationDisabled() {
        String packageName = getPackageName();
        PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
        return pm.isIgnoringBatteryOptimizations(packageName);
    }

}