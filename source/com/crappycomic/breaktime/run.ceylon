import java.awt {
    Image,
    MenuItem,
    PopupMenu,
    Rectangle,
    Robot,
    SystemTray,
    Toolkit,
    TrayIcon
}
import java.awt.image {
    BufferedImage
}
import java.lang {
    System,
    UnsupportedOperationException
}

import javax.swing {
    SwingUtilities,
    Timer
}

"The number of minutes after which it's time to take a break."
Integer periodInMinutes = 30;

"The minimum number of seconds a break should last before the icon resets."
Integer minimumBreakInSeconds = 30;

"Returns the number of milliseconds each frame should delay in order to fit `frameCount` frames in
 before it's time to take a break."
Integer computeDelay(Integer frameCount) {
    value periodInSeconds = periodInMinutes * 60;
    value periodInMilliseconds = periodInSeconds * 1000;
    
    return periodInMilliseconds / frameCount;
}

"Creates and returns a [[TrayIcon]] with the given [[initialImage]] and a popup menu that can
 [[reset]] the icon or exit the application."
TrayIcon createTrayIcon(Image initialImage, Anything(TrayIcon) reset) {
    value trayIcon = TrayIcon(initialImage, "Break time?");
    
    trayIcon.imageAutoSize = true;
    
    value resetItem = MenuItem("Reset");
    
    resetItem.addActionListener((event) => reset(trayIcon));
    
    value exitItem = MenuItem("Exit");
    
    exitItem.addActionListener((event) => System.exit(0));
    
    value popupMenu = PopupMenu();
    
    popupMenu.add(resetItem);
    popupMenu.addSeparator();
    popupMenu.add(exitItem);
    
    trayIcon.popupMenu = popupMenu;
    
    return trayIcon;
}

"Creates an image containing each frame of the icon filling up and returns it along with the number
 of frames."
[BufferedImage, Integer] createTrayIconFrames(Integer iconWidth, Integer iconHeight) {
    value marginWidth = iconWidth / 4;
    value marginHeight = iconHeight / 12;
    value border = 1;
    value outsideWidth = iconWidth - marginWidth * 2;
    value outsideHeight = iconHeight - marginHeight * 2;
    value insideWidth = outsideWidth - border * 2;
    value insideHeight = outsideHeight - border * 2;
    value frameCount = insideWidth * insideHeight + 1;
    value image = BufferedImage(iconWidth * frameCount, iconHeight, BufferedImage.typeIntArgb);
    
    for (frame in 0:frameCount) {
        value frameX = marginWidth + iconWidth * frame;
        
        for (x in frameX:outsideWidth) {
            for (y in marginHeight:outsideHeight) {
                image.setRGB(x, y, #ff_00_00_00);
            }
        }
        
        value insideX = frameX + border;
        value insideY = iconHeight - marginHeight - border - 1;
        
        for (pixel in 0:frame) {
            value x = pixel % insideWidth;
            value y = pixel / insideWidth;
            
            image.setRGB(insideX + x, insideY - y, insideColor(frame, frameCount - 1));
        }
    }
    
    // Uncomment to write the frames to disk, for debugging.
    //ImageIO.write(image, "png", File("output.png"));
    
    return [image, frameCount];
}

"Returns the color that the inside of the icon should be, linearly interpreted based on the given
 current [[frame]] and [[lastFrame]]."
Integer insideColor(Integer frame, Integer lastFrame) {
    value alpha = #ff;
    value red = #ff * frame / lastFrame;
    value green = #ff;
    value blue = #00;
    
    return alpha.leftLogicalShift(24)
            .or(red.leftLogicalShift(16))
            .or(green.leftLogicalShift(8))
            .or(blue);
}

"Returns `true` if the screen is currently locked, assuming that a locked screen will have black
 pixels in all four corners.
 
 Inspired by [this StackOverflow answer](https://stackoverflow.com/a/39420323).
 "
Boolean isScreenLocked() {
    value screen = Robot().createScreenCapture(Rectangle(Toolkit.defaultToolkit.screenSize));
    value mask = #ff_ff_ff; // Look at RGB values only, ignoring alpha.
    value maxX = screen.width - 1;
    value maxY = screen.height - 1;
    
    return screen.getRGB(0, 0).and(mask) == 0
            && screen.getRGB(0, maxY).and(mask) == 0
            && screen.getRGB(maxX, 0).and(mask) == 0
            && screen.getRGB(maxX, maxY).and(mask) == 0;
}

"Runs the application and adds the icon to the system tray, if possible."
shared void run() {
    if (!SystemTray.supported) {
        throw UnsupportedOperationException();
    }
    
    variable value frame = 0;
    value systemTray = SystemTray.systemTray;
    value iconSize = systemTray.trayIconSize;
    value iconWidth = iconSize.width.integer;
    value iconHeight = iconSize.height.integer;
    
    value [trayIconFrames, frameCount] = createTrayIconFrames(iconWidth, iconHeight);
    
    "Returns the currently displayed [[frame]] of the icon."
    function getFrame() {
        value offsetX = (frame % frameCount) * iconWidth;
        
        return trayIconFrames.getSubimage(offsetX, 0, iconWidth, iconHeight);
    }
    
    "Resets the given [[trayIcon]] to the first frame."
    void reset(TrayIcon trayIcon) {
        frame = 0;
        
        trayIcon.image = getFrame();
    }
    
    value trayIcon = createTrayIcon(getFrame(), reset);
    
    SwingUtilities.invokeLater(() => systemTray.add(trayIcon));
    
    // Increments the frame counter and updates the icon. Displays a message when it's break time!
    Timer(computeDelay(frameCount), void(Anything _) {
        if (isScreenLocked()) {
            frame = 0;
        } else if (frame < frameCount - 1) {
            frame++;
        } else {
            trayIcon.displayMessage("Break time!", "Take a break!", TrayIcon.MessageType.info);
        }
        
        trayIcon.image = getFrame();
    }).start();
    
    // Resets the icon if the screen is locked.
    Timer(minimumBreakInSeconds * 1000, void(Anything _) {
        if (isScreenLocked()) {
            reset(trayIcon);
        }
    }).start();
}
