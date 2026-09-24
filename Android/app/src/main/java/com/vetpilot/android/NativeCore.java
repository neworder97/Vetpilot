package com.vetpilot.android;
import java.nio.charset.StandardCharsets;
public final class NativeCore {
    static { System.loadLibrary("VetPilotCore"); }
    private static native byte[] dispatchBytes(byte[] request);
    public static synchronized String dispatch(String request) {
        byte[] response = dispatchBytes(request.getBytes(StandardCharsets.UTF_8));
        return response == null ? "{\"error\":\"Calculation engine unavailable\"}" : new String(response, StandardCharsets.UTF_8);
    }
}
