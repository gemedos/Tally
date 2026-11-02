package io.github.gemedos.tally;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/** Single screen: a WebView running assets/index.html. All data stays in local storage. */
public class MainActivity extends Activity {
    private static final int REQ_SAVE = 1, REQ_OPEN = 2;
    private WebView web;
    private String pendingSave;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(Color.parseColor("#0E0F12"));
        getWindow().setNavigationBarColor(Color.parseColor("#15171C"));
        web = new WebView(this);
        web.setBackgroundColor(Color.parseColor("#0E0F12"));
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(false);
        s.setMediaPlaybackRequiresUserGesture(false);
        web.setWebChromeClient(new WebChromeClient()); // enables alert()/confirm()
        web.addJavascriptInterface(new Bridge(), "Android");
        web.loadUrl("file:///android_asset/index.html");
        setContentView(web);
        if (Build.VERSION.SDK_INT >= 33) requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 1);
    }

    @Override
    public void onBackPressed() {
        web.evaluateJavascript("window.onBack&&onBack()", new ValueCallback<String>() {
            public void onReceiveValue(String v) {
                if (!"true".equals(v)) finish();
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        web.evaluateJavascript("window.onResume&&onResume()", null);
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        if (res != RESULT_OK || data == null || data.getData() == null) return;
        Uri uri = data.getData();
        try {
            if (req == REQ_SAVE && pendingSave != null) {
                try (OutputStream os = getContentResolver().openOutputStream(uri, "wt")) {
                    os.write(pendingSave.getBytes("UTF-8"));
                }
                pendingSave = null;
                Toast.makeText(this, "Backup saved", Toast.LENGTH_SHORT).show();
            } else if (req == REQ_OPEN) {
                ByteArrayOutputStream bos = new ByteArrayOutputStream();
                try (InputStream is = getContentResolver().openInputStream(uri)) {
                    byte[] buf = new byte[8192];
                    int n;
                    while ((n = is.read(buf)) > 0) bos.write(buf, 0, n);
                }
                web.evaluateJavascript("onImported(" + JSONObject.quote(bos.toString("UTF-8")) + ")", null);
            }
        } catch (Exception e) {
            Toast.makeText(this, "Error: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    static final String AUTO_NAME = "tally-autobackup.json", AUTO_DIR = "Tally";

    /** Writes the backup to Download/Tally/, which survives uninstalling the app. */
    boolean writeAutoBackup(String json) throws Exception {
        byte[] data = json.getBytes("UTF-8");
        if (Build.VERSION.SDK_INT >= 29) {
            ContentResolver cr = getContentResolver();
            Uri col = MediaStore.Downloads.EXTERNAL_CONTENT_URI;
            String rel = Environment.DIRECTORY_DOWNLOADS + "/" + AUTO_DIR + "/";
            Uri uri = null;
            // only finds the file if this install created it; after a reinstall a new one is made
            Cursor c = cr.query(col, new String[]{MediaStore.MediaColumns._ID},
                    MediaStore.MediaColumns.DISPLAY_NAME + "=? AND " + MediaStore.MediaColumns.RELATIVE_PATH + "=?",
                    new String[]{AUTO_NAME, rel}, null);
            if (c != null) {
                if (c.moveToFirst()) uri = ContentUris.withAppendedId(col, c.getLong(0));
                c.close();
            }
            if (uri == null) {
                ContentValues v = new ContentValues();
                v.put(MediaStore.MediaColumns.DISPLAY_NAME, AUTO_NAME);
                v.put(MediaStore.MediaColumns.MIME_TYPE, "application/json");
                v.put(MediaStore.MediaColumns.RELATIVE_PATH, rel);
                uri = cr.insert(col, v);
                if (uri == null) return false;
            }
            OutputStream os = cr.openOutputStream(uri, "wt");
            try { os.write(data); } finally { os.close(); }
            return true;
        }
        if (checkSelfPermission("android.permission.WRITE_EXTERNAL_STORAGE") != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{"android.permission.WRITE_EXTERNAL_STORAGE"}, 2);
            return false;
        }
        File dir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), AUTO_DIR);
        if (!dir.exists() && !dir.mkdirs()) return false;
        FileOutputStream os = new FileOutputStream(new File(dir, AUTO_NAME));
        try { os.write(data); } finally { os.close(); }
        return true;
    }

    class Bridge {
        @JavascriptInterface
        public boolean autoBackup(String json) {
            try { return writeAutoBackup(json); } catch (Exception e) { return false; }
        }

        @JavascriptInterface
        public void save(String name, String text) {
            pendingSave = text;
            Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("application/json").putExtra(Intent.EXTRA_TITLE, name);
            startActivityForResult(i, REQ_SAVE);
        }

        @JavascriptInterface
        public void open() {
            Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*");
            startActivityForResult(i, REQ_OPEN);
        }

        @JavascriptInterface
        public void alarmAt(double epochMillis) {
            RestAlarm.schedule(MainActivity.this, (long) epochMillis);
        }

        @JavascriptInterface
        public void cancelAlarm() {
            RestAlarm.cancel(MainActivity.this);
        }

        @JavascriptInterface
        public void vibrate(int ms) {
            Vibrator v = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
            if (v == null) return;
            if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE));
            else v.vibrate(ms);
        }

        @JavascriptInterface
        public void keepScreenOn(final boolean on) {
            runOnUiThread(new Runnable() {
                public void run() {
                    if (on) getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                    else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                }
            });
        }
    }
}
