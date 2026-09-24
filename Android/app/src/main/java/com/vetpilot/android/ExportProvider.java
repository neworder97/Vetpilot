package com.vetpilot.android;
import android.content.*;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.*;
public final class ExportProvider extends ContentProvider {
 public boolean onCreate() { return true; }
 private File file(Uri uri) throws FileNotFoundException {
  String name=uri.getLastPathSegment();
  if(name==null || !name.matches("VetPilot-[A-Za-z0-9-]+\\.(pdf|vetpilot)")) throw new FileNotFoundException();
  File f=new File(getContext().getCacheDir(),"exports/"+name);
  if(!f.isFile()) throw new FileNotFoundException(); return f;
 }
 public String getType(Uri uri) { return uri.toString().endsWith(".pdf") ? "application/pdf" : "application/vnd.vetpilot.clinic+json"; }
 public ParcelFileDescriptor openFile(Uri uri,String mode) throws FileNotFoundException {
  if(!"r".equals(mode)) throw new FileNotFoundException("Read only"); return ParcelFileDescriptor.open(file(uri),ParcelFileDescriptor.MODE_READ_ONLY);
 }
 public Cursor query(Uri uri,String[] projection,String selection,String[] args,String sort) {
  String[] columns=projection!=null ? projection : new String[]{OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE};
  MatrixCursor c=new MatrixCursor(columns);
  try { File f=file(uri);Object[] row=new Object[columns.length];for(int i=0;i<columns.length;i++) row[i]=OpenableColumns.DISPLAY_NAME.equals(columns[i])?f.getName():OpenableColumns.SIZE.equals(columns[i])?f.length():null;c.addRow(row); } catch(Exception ignored){} return c;
 }
 public Uri insert(Uri u,ContentValues v){throw new UnsupportedOperationException();}
 public int delete(Uri u,String s,String[] a){throw new UnsupportedOperationException();}
 public int update(Uri u,ContentValues v,String s,String[] a){throw new UnsupportedOperationException();}
}
