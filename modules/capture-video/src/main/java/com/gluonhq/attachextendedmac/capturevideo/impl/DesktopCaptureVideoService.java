/*
 * Copyright (c) 2022, Gluon
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL GLUON BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
package com.gluonhq.attachextendedmac.capturevideo.impl;

import com.gluonhq.attachextendedmac.capturevideo.CaptureVideoService;
import com.gluonhq.attachextendedmac.capturevideo.Frame;
import javafx.application.Platform;
import javafx.beans.property.ReadOnlyObjectProperty;
import javafx.beans.property.ReadOnlyObjectWrapper;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.logging.Level;
import java.util.logging.Logger;

public class DesktopCaptureVideoService implements CaptureVideoService {

    private static final Logger LOG = Logger.getLogger(DesktopCaptureVideoService.class.getName());

    private static final String OS_NAME  = System.getProperty("os.name").toLowerCase(Locale.ROOT);

    static {
        if (OS_NAME.contains("mac")) {
            Path path = Path.of(System.getProperty("user.home"), ".gluon", "libs", "libCaptureVideo.dylib");
            if (Files.exists(path)) {
                System.load(path.toString());
                initCaptureVideo();
            } else {
                LOG.log(Level.SEVERE, "Library not found at " + path);
            }
        }
    }

    private static final ReadOnlyObjectWrapper<Frame> frameProperty = new ReadOnlyObjectWrapper<>();

    @Override
    public void start() {
        frameProperty.setValue(null);
        nativeStart();
    }

    @Override
    public void stop() {
        nativeStop();
        frameProperty.setValue(null);
    }

    @Override
    public ReadOnlyObjectProperty<Frame> frameProperty() {
        return frameProperty.getReadOnlyProperty();
    }

    private static native void initCaptureVideo();
    private static native void nativeStart();
    private static native void nativeStop();

    // callback
    public static void setResult(int width, int height, byte[] data) {
        if (data != null) {
            Frame f = new Frame(width, height, data);
            Platform.runLater(() -> frameProperty.setValue(f));
        }
    }
}
