1.  snappingSheetController is the class used to implement the controller pattern
    in the snapping_sheet library.
    With this controller the developer can control the sheet. for example, the developer can change
    the positions of the sheet, and stop it midway.
    The developer can also extract information about the sheet. for example,
    the current location of the sheet.

2.  snappingCurve, used with snappingDuration is the parameter that controls the behavior of
    snapping animations. Those can be declared in SnappingPositions.factor that is contained within
    snappingPositions, that is declared in the build method of SnappingSheet.

3.  One advantage of InkWell over GestureDetector is that InkWell provides a visual ripple effect
    that GestureDetector does not provide.
    One advantage of GestureDetector over InkWell is that with GestureDetector you can detect every
    type of interaction the user has with the screen or widget using it, Like pinch and swipe gestures.
    on the other hand, InkWell has limited gestures he can detect.
    
    
![Its Free Real Estate 255](https://user-images.githubusercontent.com/63237643/165128944-d93e8f6a-69dc-4e51-b3ca-b5fba7481a6d.jpg)
