package org.opencv.engine;

import android.os.IBinder;
import android.os.IInterface;
import android.os.RemoteException;

/**
 * Minimal stub replacement for the original AIDL-generated interface.
 * It satisfies compilation needs for OpenCV's Android helpers without relying on the service-backed engine.
 */
public interface OpenCVEngineInterface extends IInterface {
    int getEngineVersion() throws RemoteException;

    String getLibPathByVersion(String version) throws RemoteException;

    boolean installVersion(String version) throws RemoteException;

    String getLibraryList(String version) throws RemoteException;

    abstract class Stub implements OpenCVEngineInterface {
        public static OpenCVEngineInterface asInterface(IBinder binder) {
            return null;
        }
    }
}
