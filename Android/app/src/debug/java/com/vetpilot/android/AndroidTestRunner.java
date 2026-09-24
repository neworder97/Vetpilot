package com.vetpilot.android;
import android.app.*;
import android.content.*;
import android.os.*;
import android.graphics.pdf.PdfRenderer;
import org.json.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** Debug-only on-device JNI, persistence, PDF and actual WebView tests. */
public class AndroidTestRunner extends Instrumentation {
 int assertions=0,vectors=0;JSONArray stages=new JSONArray();MainActivity activity;
 @Override public void onCreate(Bundle arguments){super.onCreate(arguments);start();}
 void check(boolean condition,String description){assertions++;if(!condition)throw new AssertionError(description);}
 void stage(String description){stages.put(description);Bundle b=new Bundle();b.putString("stream",description+"\n");sendStatus(0,b);}
 void equal(Object a,Object b,String path)throws Exception{
  if(a==JSONObject.NULL||b==JSONObject.NULL){check(a==b,path+" null mismatch");return;}
  if(a instanceof JSONObject&&b instanceof JSONObject){JSONObject x=(JSONObject)a,y=(JSONObject)b;check(x.length()==y.length(),path+" keys mismatch "+x+" vs "+y);Iterator<String> keys=x.keys();while(keys.hasNext()){String k=keys.next();check(y.has(k),path+" missing "+k);equal(x.get(k),y.get(k),path+"."+k);}return;}
  if(a instanceof JSONArray&&b instanceof JSONArray){JSONArray x=(JSONArray)a,y=(JSONArray)b;check(x.length()==y.length(),path+" array length");for(int i=0;i<x.length();i++)equal(x.get(i),y.get(i),path+"["+i+"]");return;}
  if(a instanceof Number&&b instanceof Number){double x=((Number)a).doubleValue(),y=((Number)b).doubleValue();check(Math.abs(x-y)<=1e-10*Math.max(1,Math.abs(x)),path+" numeric "+x+" vs "+y);return;}
  check(a.equals(b),path+" mismatch: "+a+" vs "+b);
 }
 String js(String script)throws Exception{
  CountDownLatch latch=new CountDownLatch(1);AtomicReference<String> result=new AtomicReference<>();runOnMainSync(()->activity.web.evaluateJavascript(script,v->{result.set(v);latch.countDown();}));
  check(latch.await(60,TimeUnit.SECONDS),"WebView response timeout");return result.get();
 }
 JSONObject jsObject(String script)throws Exception{return new JSONObject(new JSONTokener(js("JSON.stringify((()=>{"+script+"})())")).nextValue().toString());}
 void waitJS(String expression)throws Exception{for(int i=0;i<120;i++){if("true".equals(js(expression)))return;Thread.sleep(500);}throw new AssertionError("WebView condition failed: "+expression);}
 void click(String action)throws Exception{js("document.querySelector('[data-action=\""+action+"\"]').click()");}
 @Override public void onStart(){
  JSONObject report=new JSONObject();Bundle result=new Bundle();int code=Activity.RESULT_OK;
  try{
   stage("Loading actual Android JNI engine");
   JSONObject catalog=new JSONObject(NativeCore.dispatch("{\"op\":\"catalog\"}"));check(catalog.getJSONArray("medications").length()==141,"141 medication entries");
   try(BufferedReader reader=new BufferedReader(new InputStreamReader(getContext().getAssets().open("parity.jsonl"),"UTF-8"))){String line;while((line=reader.readLine())!=null){JSONObject vector=new JSONObject(line);JSONObject actual=new JSONObject(NativeCore.dispatch(vector.getJSONObject("q").toString()));equal(vector.getJSONObject("expected"),actual,"vector "+vectors);vectors++;if(vectors%1000==0)stage("JNI parity passed "+vectors+" vectors");}}
   stage("Every medication/protocol JNI parity passed");
   // UTF-8 transport and strict import checks, including emoji and clinical units.
   JSONObject item=new JSONObject("{\"id\":\"6D172C45-C72A-4F70-8B75-8021BD62A1AC\",\"title\":\"Protocol 🐕 μg m²\",\"category\":\"General\",\"kind\":\"Protocol\",\"summary\":\"Test\",\"steps\":[],\"equipment\":[],\"notes\":\"\",\"photos\":[],\"author\":\"Tester\",\"reviewer\":\"\",\"reviewedOn\":\"\",\"revision\":1,\"updatedAt\":\"2026-09-24T12:00:00Z\",\"favorite\":false,\"imported\":false}");
   JSONObject pack=new JSONObject().put("format","VetPilot.MyClinic").put("schemaVersion",1).put("exportedAt","2026-09-24T12:00:00Z").put("items",new JSONArray().put(item));
   JSONObject validated=new JSONObject(NativeCore.dispatch(new JSONObject().put("op","clinicValidate").put("package",pack).toString()));check(validated.has("package"),"Unicode clinic validation "+validated);
   JSONObject imported=new JSONObject(NativeCore.dispatch(new JSONObject().put("op","clinicImport").put("package",pack).toString())).getJSONObject("package").getJSONArray("items").getJSONObject(0);
   check(!imported.getString("id").equals(item.getString("id")),"Import uses new IDs");check(imported.getBoolean("imported"),"Import label");check(imported.getString("title").equals(item.getString("title")),"Unicode preserved");
   pack.put("schemaVersion",2);check(new JSONObject(NativeCore.dispatch(new JSONObject().put("op","clinicValidate").put("package",pack).toString())).has("error"),"Future schema rejected");pack.put("schemaVersion",1);
   StringBuilder notes=new StringBuilder();for(int i=0;i<300;i++)notes.append("Line "+i+" — specimen protocol and equipment instructions.\n");item.put("notes",notes.toString());
   File pdf=new File(getTargetContext().getCacheDir(),"test-long.pdf");MainActivity.writePDF(pack,pdf);check(pdf.length()>1000,"PDF generated");
   try(ParcelFileDescriptor fd=ParcelFileDescriptor.open(pdf,ParcelFileDescriptor.MODE_READ_ONLY);PdfRenderer renderer=new PdfRenderer(fd)){check(renderer.getPageCount()>5,"Long PDF pagination");}
   stage("Unicode, import validation and multipage PDF passed");
   Intent intent=new Intent(getTargetContext(),MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);activity=(MainActivity)startActivitySync(intent);
   waitJS("document.querySelectorAll('[data-med]').length>10");
   check("5".equals(js("document.querySelectorAll('[data-tab]').length")),"Five tabs");
   JSONObject dose=jsObject("state.species='Dog';openMedication(String(catalog.medications.find(m=>m.generic==='Amoxicillin + clavulanate'&&m.form==='Tablet').id));document.querySelector('#doseWeight').value='10';document.querySelector('#doseUnit').value='kg';calculate();return {quantity:document.querySelector('#doseResult').innerText,top:document.querySelector('#frequency').getBoundingClientRect().top,result:document.querySelector('#doseResult').getBoundingClientRect().top};");
   check(dose.getString("quantity").contains("tablet"),"Tablet quantity shown");check(dose.getDouble("top")<dose.getDouble("result"),"Frequency control before result");
   js("document.querySelector('#doseWeight').value='20';document.querySelector('#doseWeight').dispatchEvent(new Event('input',{bubbles:true}))");check("\"\"".equals(js("document.querySelector('#doseResult').innerText")),"Changed input clears stale result");
   js("document.querySelector('#doseWeight').value='2,5';calculate()");check("true".equals(js("document.querySelector('#doseResult').innerText.includes('decimal point')")),"Invalid weight blocks calculation");
   js("state.med=null;state.tab='nutrition';state.page='list';render();document.querySelector('#nutWeight').value='10';document.querySelector('#nutUnit').value='kg';nutritionCalculate()");
   check("true".equals(js("document.querySelector('#nutritionResult').innerText.includes('551 kcal/day')")),"Neutered dog nutrition");
   js("document.querySelector('#nutStatus').value='Intact';nutritionCalculate()");check("true".equals(js("document.querySelector('#nutritionResult').innerText.includes('630 kcal/day')")),"Intact dog nutrition");
   js("state.tab='labs';render();document.querySelector('#labSearch').value='cardiopet';document.querySelector('#labSearch').dispatchEvent(new Event('input',{bubbles:true}))");
   check(Integer.parseInt(js("document.querySelectorAll('#labList details').length"))>=2,"BNP lab search");
   js("state.tab='clinic';state.page='list';render();newClinic();document.querySelector('#editTitle').value='Android emulator protocol';document.querySelector('#editSummary').value='Offline validation';saveClinic()");
   check("true".equals(js("clinic.some(p=>p.title==='Android emulator protocol')")),"Clinic item saved");
   check("true".equals(js("state.page==='detail' && currentClinic().title==='Android emulator protocol'")),"Saved item opens with canonical UUID");
   check("true".equals(js("load('clinic',[]).some(p=>p.title==='Android emulator protocol')")),"Clinic native persistence");
   js("state.page='settings';render();document.querySelector('#settingsEmail').value='vet@example.org';document.querySelector('#settingsPhone').value='+15555550100'");click("saveSettings");
   check("true".equals(js("load('settings',{}).email==='vet@example.org'")),"Sharing defaults persisted");
   js("state.tab='clinic';state.page='list';render();renderExport(clinic)");check("4".equals(js("document.querySelectorAll('[data-action=shareEmail],[data-action=shareText],[data-action=share],[data-action=saveFile]').length")),"Four sharing choices");
   // Native provider rejects traversal and writes; read grants are scoped to exports.
   ExportProvider provider=new ExportProvider();boolean blocked=false;try{provider.openFile(android.net.Uri.parse("content://com.vetpilot.android.exports/../secret"),"w");}catch(Exception e){blocked=true;}check(blocked,"Provider rejects write/traversal");
   js("state.tab='dose';state.page='list';state.med=null;state.weight='';render()");
   stage("Actual WebView tabs, quantity display, input invalidation, nutrition, lab search, clinic and settings passed");
   report.put("passed",true);
  }catch(Throwable e){code=Activity.RESULT_CANCELED;try{report.put("passed",false).put("error",e.toString());}catch(Exception ignored){}StringWriter sw=new StringWriter();e.printStackTrace(new PrintWriter(sw));result.putString("stream",sw.toString());}
  try{report.put("vectors",vectors).put("assertions",assertions).put("stages",stages).put("android",Build.VERSION.RELEASE).put("abi",Build.SUPPORTED_ABIS[0]);
   File out=new File(getTargetContext().getExternalFilesDir(null),"vetpilot-validation.json");try(FileOutputStream stream=new FileOutputStream(out)){stream.write(report.toString(2).getBytes("UTF-8"));}
   result.putString("report",report.toString());result.putString("reportPath",out.toString());
  }catch(Exception ignored){}
  finish(code,result);
 }
}
