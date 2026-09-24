package com.vetpilot.android;

import android.app.*;
import android.content.*;
import android.graphics.*;
import android.graphics.pdf.PdfDocument;
import android.media.ExifInterface;
import android.net.Uri;
import android.os.*;
import android.util.AtomicFile;
import android.util.Base64;
import android.view.*;
import android.webkit.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class MainActivity extends Activity {
 WebView web; File pendingExport; Uri launchImport;
 static final int IMPORT=10, SAVE=11, PHOTO=12;
 static final String ORIGIN="https://appassets.vetpilot.invalid/";
 @Override public void onCreate(Bundle state) {
  super.onCreate(state);
  getWindow().setStatusBarColor(Color.rgb(20,73,156));
  getWindow().setNavigationBarColor(Color.WHITE);
  web=new WebView(this);setContentView(web);
  // Respect system bars, including Android 15's edge-to-edge default.
  web.setOnApplyWindowInsetsListener((v,insets)->{v.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets;});
  web.getSettings().setJavaScriptEnabled(true);web.getSettings().setDomStorageEnabled(true);
  web.getSettings().setAllowFileAccess(false);web.getSettings().setAllowContentAccess(false);
  web.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
  web.getSettings().setTextZoom(100);
  WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
  web.addJavascriptInterface(new Bridge(),"Android");
  web.setWebChromeClient(new WebChromeClient(){
   public boolean onJsAlert(WebView v,String u,String message,JsResult r){new AlertDialog.Builder(MainActivity.this).setMessage(message).setPositiveButton("OK",(d,w)->r.confirm()).setOnCancelListener(d->r.cancel()).show();return true;}
   public boolean onJsConfirm(WebView v,String u,String message,JsResult r){new AlertDialog.Builder(MainActivity.this).setMessage(message).setPositiveButton("Continue",(d,w)->r.confirm()).setNegativeButton("Cancel",(d,w)->r.cancel()).setOnCancelListener(d->r.cancel()).show();return true;}
  });
  web.setWebViewClient(new WebViewClient(){
   @Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request){
    String url=request.getUrl().toString();
    if(!url.startsWith(ORIGIN))return new WebResourceResponse("text/plain","utf-8",new ByteArrayInputStream(new byte[0]));
    String path=request.getUrl().getPath().substring(1);
    if(!Arrays.asList("index.html","app.js","style.css","icon.png","THIRD-PARTY-NOTICES.txt").contains(path))return new WebResourceResponse("text/plain","utf-8",new ByteArrayInputStream(new byte[0]));
    try{return new WebResourceResponse(path.endsWith("js")?"application/javascript":path.endsWith("css")?"text/css":path.endsWith("png")?"image/png":path.endsWith("txt")?"text/plain":"text/html","utf-8",getAssets().open(path));}catch(Exception e){return null;}
   }
   @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){
    Uri u=r.getUrl();if(u.toString().startsWith(ORIGIN))return false;
    if("https".equals(u.getScheme())||"http".equals(u.getScheme()))try{startActivity(new Intent(Intent.ACTION_VIEW,u));}catch(Exception e){event("error","No browser is installed.");}return true;
   }
   @Override public void onPageFinished(WebView v,String url){if(launchImport!=null){Uri u=launchImport;launchImport=null;readImport(u);}}
  });
  if(Intent.ACTION_VIEW.equals(getIntent().getAction()))launchImport=getIntent().getData();
  web.loadUrl(ORIGIN+"index.html");
 }
 @Override protected void onNewIntent(Intent intent){super.onNewIntent(intent);if(intent.getData()!=null)readImport(intent.getData());}
 @Override public void onBackPressed(){if(web.canGoBack()){web.goBack();return;}web.evaluateJavascript("window.goBack && window.goBack()",null);}
 void event(String type,Object value){runOnUiThread(()->{try{JSONObject data=new JSONObject();data.put("type",type);data.put("value",value);web.evaluateJavascript("window.nativeEvent("+data+")",null);}catch(Exception ignored){}});}
 static byte[] readLimited(InputStream stream,int max)throws IOException{
  if(stream==null)throw new IOException("Unable to open file");try(InputStream in=stream;ByteArrayOutputStream out=new ByteArrayOutputStream()){
   byte[] b=new byte[16384];int n,total=0;while((n=in.read(b))!=-1){total+=n;if(total>max)throw new IOException("File is too large");out.write(b,0,n);}return out.toByteArray();
  }
 }
 void readImport(Uri uri){new Thread(()->{try{
  byte[] data=readLimited(getContentResolver().openInputStream(uri),15000000);
  JSONObject q=new JSONObject().put("op","clinicValidate").put("package",new JSONObject(new String(data,StandardCharsets.UTF_8)));
  JSONObject result=new JSONObject(NativeCore.dispatch(q.toString()));if(result.has("error"))throw new IOException(result.getString("error"));
  validatePhotos(result.getJSONObject("package"));event("import",result.getJSONObject("package"));
 }catch(Exception e){event("error","Import failed: "+e.getMessage());}}).start();}
 static void validatePhotos(JSONObject pack)throws Exception{
  JSONArray items=pack.getJSONArray("items");for(int i=0;i<items.length();i++){
   JSONArray photos=items.getJSONObject(i).getJSONArray("photos");for(int j=0;j<photos.length();j++){
    byte[] b=Base64.decode(photos.getJSONObject(j).getString("jpeg"),Base64.DEFAULT);BitmapFactory.Options o=new BitmapFactory.Options();o.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(b,0,b.length,o);
    if(o.outWidth<1||o.outHeight<1||o.outWidth>4096||o.outHeight>4096)throw new IOException("Photo is invalid or exceeds 4096 pixels");
   }
  }
 }
 final class Bridge {
  @JavascriptInterface public String request(String input){
   try{
    JSONObject q=new JSONObject(input);String op=q.optString("native");
    if(op.isEmpty())return NativeCore.dispatch(input);
    switch(op){
     case "load":{String key=storageKey(q);File f=new File(getFilesDir(),key+".json");return f.exists()?new String(readLimited(new FileInputStream(f),50000000),StandardCharsets.UTF_8):"null";}
     case "save":{String key=storageKey(q);String data=q.get("value").toString();if(data.getBytes(StandardCharsets.UTF_8).length>50000000)throw new IOException("Storage limit exceeded");
      AtomicFile f=new AtomicFile(new File(getFilesDir(),key+".json"));FileOutputStream out=null;try{out=f.startWrite();out.write(data.getBytes(StandardCharsets.UTF_8));f.finishWrite(out);}catch(Exception e){if(out!=null)f.failWrite(out);throw e;}return "{\"ok\":true}";}
     case "import":runOnUiThread(()->{try{Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*").addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(i,IMPORT);}catch(Exception e){event("error","No file picker is available.");}});return "{}";
     case "photo":runOnUiThread(()->{try{startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE),PHOTO);}catch(Exception e){event("error","No photo picker is available.");}});return "{}";
     case "export":export(q);return "{\"ok\":true}";
     default:throw new IOException("Unsupported action");
    }
   }catch(Exception e){try{return new JSONObject().put("error",e.getMessage()==null?"Action failed":e.getMessage()).toString();}catch(Exception ignored){return "{\"error\":\"Action failed\"}";}}
  }
  String storageKey(JSONObject q)throws Exception{String key=q.getString("key");if(!Arrays.asList("clinic","settings","custom","overrides").contains(key))throw new IOException("Unsupported storage key");return key;}
 }
 void export(JSONObject q)throws Exception {
  JSONObject validated=new JSONObject(NativeCore.dispatch(new JSONObject().put("op","clinicValidate").put("package",q.getJSONObject("package")).toString()));
  if(validated.has("error"))throw new IOException(validated.getString("error"));JSONObject pack=validated.getJSONObject("package");validatePhotos(pack);
  boolean pdf="pdf".equals(q.optString("format"));String channel=q.optString("channel","share");
  File dir=new File(getCacheDir(),"exports");dir.mkdirs();
  File[] old=dir.listFiles();if(old!=null)for(File f:old)if(System.currentTimeMillis()-f.lastModified()>7L*86400000)f.delete();
  File file=new File(dir,"VetPilot-"+System.currentTimeMillis()+"-"+UUID.randomUUID().toString().substring(0,8)+(pdf?".pdf":".vetpilot"));
  if(pdf)writePDF(pack,file);else try(FileOutputStream out=new FileOutputStream(file)){out.write(pack.toString(2).getBytes(StandardCharsets.UTF_8));}
  runOnUiThread(()->{try{
   if("save".equals(channel)){pendingExport=file;startActivityForResult(new Intent(Intent.ACTION_CREATE_DOCUMENT).setType(pdf?"application/pdf":"application/octet-stream").putExtra(Intent.EXTRA_TITLE,file.getName()).addCategory(Intent.CATEGORY_OPENABLE),SAVE);return;}
   Uri uri=Uri.parse("content://com.vetpilot.android.exports/"+file.getName());Intent intent=new Intent(Intent.ACTION_SEND).setType(pdf?"application/pdf":"application/octet-stream");
   intent.putExtra(Intent.EXTRA_STREAM,uri);intent.setClipData(ClipData.newRawUri("VetPilot export",uri));intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
   intent.putExtra(Intent.EXTRA_SUBJECT,"VetPilot — clinic protocols for review");intent.putExtra(Intent.EXTRA_TEXT,"Shared from VetPilot. User-created content requires clinical review before use.");
   if("email".equals(channel)&&!q.optString("email").isEmpty())intent.putExtra(Intent.EXTRA_EMAIL,new String[]{q.optString("email")});
   if("text".equals(channel)&&!q.optString("phone").isEmpty()){intent.putExtra("address",q.optString("phone"));intent.putExtra("sms_body","VetPilot clinic protocols — review before use.");}
   startActivity(Intent.createChooser(intent,"email".equals(channel)?"Choose your email app":"text".equals(channel)?"Choose your messaging app":"Share VetPilot file"));
  }catch(Exception e){event("error","No compatible app is available. Choose Save to Files instead.");}});
 }
 @Override protected void onActivityResult(int request,int result,Intent data){
  super.onActivityResult(request,result,data);if(result!=RESULT_OK||data==null||data.getData()==null)return;Uri uri=data.getData();
  if(request==IMPORT)readImport(uri);
  if(request==SAVE){File file=pendingExport;pendingExport=null;if(file==null){event("error","Please export the file again.");return;}new Thread(()->{try(InputStream in=new FileInputStream(file);OutputStream out=getContentResolver().openOutputStream(uri)){if(out==null)throw new IOException();byte[] b=new byte[16384];int n;while((n=in.read(b))!=-1)out.write(b,0,n);event("saved","File saved to your chosen location.");}catch(Exception e){event("error","Could not save file.");}}).start();}
  if(request==PHOTO)new Thread(()->{try{
   byte[] b=readLimited(getContentResolver().openInputStream(uri),25000000);BitmapFactory.Options o=new BitmapFactory.Options();o.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(b,0,b.length,o);
   if(o.outWidth<1||o.outHeight<1||((long)o.outWidth)*o.outHeight>100000000)throw new IOException("Unsupported image dimensions");
   int sample=1;while(Math.max(o.outWidth,o.outHeight)/sample>2400)sample*=2;o.inJustDecodeBounds=false;o.inSampleSize=sample;Bitmap bitmap=BitmapFactory.decodeByteArray(b,0,b.length,o);if(bitmap==null)throw new IOException("Invalid image");
   float scale=Math.min(1f,1600f/Math.max(bitmap.getWidth(),bitmap.getHeight()));Bitmap resized=Bitmap.createScaledBitmap(bitmap,Math.max(1,Math.round(bitmap.getWidth()*scale)),Math.max(1,Math.round(bitmap.getHeight()*scale)),true);
   int orientation=ExifInterface.ORIENTATION_NORMAL;
   try{orientation=new ExifInterface(new ByteArrayInputStream(b)).getAttributeInt(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_NORMAL);}catch(IOException ignored){ /* Valid decoded image without supported EXIF. */ }
   Matrix transform=new Matrix();switch(orientation){
    case ExifInterface.ORIENTATION_FLIP_HORIZONTAL:transform.setScale(-1,1);break;
    case ExifInterface.ORIENTATION_ROTATE_180:transform.setRotate(180);break;
    case ExifInterface.ORIENTATION_FLIP_VERTICAL:transform.setScale(1,-1);break;
    case ExifInterface.ORIENTATION_TRANSPOSE:transform.setRotate(90);transform.postScale(-1,1);break;
    case ExifInterface.ORIENTATION_ROTATE_90:transform.setRotate(90);break;
    case ExifInterface.ORIENTATION_TRANSVERSE:transform.setRotate(270);transform.postScale(-1,1);break;
    case ExifInterface.ORIENTATION_ROTATE_270:transform.setRotate(270);break;
   }
   if(!transform.isIdentity()){Bitmap oriented=Bitmap.createBitmap(resized,0,0,resized.getWidth(),resized.getHeight(),transform,true);if(resized!=bitmap)resized.recycle();resized=oriented;}
   ByteArrayOutputStream out=new ByteArrayOutputStream();resized.compress(Bitmap.CompressFormat.JPEG,78,out);if(out.size()>2000000)throw new IOException("Photo exceeds 2 MB");
   event("photo",new JSONObject().put("id",UUID.randomUUID().toString()).put("caption","").put("jpeg",Base64.encodeToString(out.toByteArray(),Base64.NO_WRAP)));if(resized!=bitmap)resized.recycle();bitmap.recycle();
  }catch(Exception e){event("error","Photo could not be added: "+e.getMessage());}}).start();
 }
 static void writePDF(JSONObject pack,File file)throws Exception{
  PdfDocument document=new PdfDocument();
  try{
   PDFWriter w=new PDFWriter(document);JSONArray items=pack.getJSONArray("items");
   for(int i=0;i<items.length();i++){
    if(i>0)w.newPage();JSONObject p=items.getJSONObject(i);w.line("VetPilot • My Clinic",13,true);w.line(p.getString("title"),21,true);
    w.line("User-created protocol — review before clinical use",11,true);
    for(String key:new String[]{"kind","category","summary","author","reviewer","reviewedOn","revision","updatedAt"})if(!p.optString(key).isEmpty())w.line(key+": "+p.optString(key),11,false);
    w.line("Review names and dates are supplied by the author and are not authenticated by VetPilot.",10,false);
    JSONArray steps=p.getJSONArray("steps");for(int j=0;j<steps.length();j++)w.line((j+1)+". "+steps.getJSONObject(j).getString("text"),12,false);
    JSONArray equipment=p.getJSONArray("equipment");if(equipment.length()>0)w.line("Equipment",14,true);
    for(int j=0;j<equipment.length();j++){JSONObject e=equipment.getJSONObject(j);w.line(e.optString("name")+" • Quantity: "+e.optString("quantity")+" • Size: "+e.optString("size")+" • Location: "+e.optString("location"),11,false);}
    w.line(p.optString("notes"),11,false);JSONArray photos=p.getJSONArray("photos");for(int j=0;j<photos.length();j++){JSONObject photo=photos.getJSONObject(j);byte[] b=Base64.decode(photo.getString("jpeg"),Base64.DEFAULT);Bitmap bitmap=BitmapFactory.decodeByteArray(b,0,b.length);if(bitmap!=null){w.image(bitmap);bitmap.recycle();}w.line(photo.optString("caption"),10,false);}
   }
   w.finish();try(FileOutputStream out=new FileOutputStream(file)){document.writeTo(out);}
  } finally { document.close(); }
 }
 static class PDFWriter{
  final PdfDocument doc;PdfDocument.Page page;Canvas canvas;Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);int pageNumber;float y;
  PDFWriter(PdfDocument d){doc=d;newPage();}
  void newPage(){finish();page=doc.startPage(new PdfDocument.PageInfo.Builder(595,842,++pageNumber).create());canvas=page.getCanvas();y=44;}
  void finish(){if(page!=null){paint.setTextSize(9);paint.setTypeface(Typeface.DEFAULT);canvas.drawText("VetPilot • Page "+pageNumber,36,817,paint);doc.finishPage(page);page=null;}}
  void line(String text,int size,boolean bold){if(text==null||text.isEmpty())return;paint.setTextSize(size);paint.setTypeface(bold?Typeface.DEFAULT_BOLD:Typeface.DEFAULT);
   for(String paragraph:text.split("\n",-1)){String rest=paragraph;if(rest.isEmpty()){y+=size+5;continue;}while(!rest.isEmpty()){
    if(y+size+6>790){newPage();paint.setTextSize(size);paint.setTypeface(bold?Typeface.DEFAULT_BOLD:Typeface.DEFAULT);}
    int n=paint.breakText(rest,true,523,null);if(n<1)n=1;if(n<rest.length()){int space=rest.lastIndexOf(' ',n);if(space>0)n=space;}
    canvas.drawText(rest.substring(0,n),36,y+size,paint);y+=size+6;rest=rest.substring(n).replaceFirst("^\\s+", "");
   }}y+=5;
  }
  void image(Bitmap bitmap){float scale=Math.min(523f/bitmap.getWidth(),300f/bitmap.getHeight());float h=bitmap.getHeight()*scale;if(y+h>790)newPage();canvas.drawBitmap(bitmap,null,new RectF(36,y,36+bitmap.getWidth()*scale,y+h),paint);y+=h+10;}
 }
}
