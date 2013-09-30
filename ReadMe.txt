MultiDocumentPlusUUID is a working example of an iOS 7 application with cloud-syncing UIManagedDocuments.
This project is open-sourced and released under the MIT License.
________________________

Purpose:
MultiDocumentPlusUUID provides a limited working example of cloud-syncing of UIManagedDocuments. 
The app demonstrates how to use UUIDs to distinguish documents of the same name.
Each document has its own UUID to distinguish it from any documents with the same file name, e.g., “Untitled”, made on different devices.
A document's UUID precedes its file name in both its sandbox and cloud URLs.
It can also provide statistics on update latencies.

________________________

Reference:
WWDC 2013 Video - Session 207 [What’s New in Core Data and iCloud](https://developer.apple.com/wwdc/videos/index.php?id=207)

Credits:
Richard Warren, author of "Creating iOS 5 Apps," provides the MultiDocument sample code:
See: Freelance Mad Science Labs - Blog - Syncing multiple Core Data documents using iCloud

See also Drew McCormack's note: Under the Sheets with iCloud and Core Data: Troubleshooting
“Unfortunately, the most apt conclusion is probably that iCloud syncing of Core Data is not really ready for prime time, at least not for any app with a complex data model. If you have a simple model, and patience, it is doable, even if very few have achieved a shipping app at this point.”
http://mentalfaculty.tumblr.com/post/25241910449/under-the-sheets-with-icloud-and-core-data

See also Erica Sudun’s iOS 5 Developer’s Cookbook:
http://books.google.com/books?id=YeHQzA6UrcEC&pg=PT1173&lpg=PT1173&dq=yorn+BOOL+ios&source=bl&ots=vynUYXoVpH&sig=PCjk79J9uGt0EHHNgNF28JpQ-HA&hl=en&sa=X&ei=euGFT6K2BY-s8ATBgvyXCA&ved=0CB4Q6AEwAA#v=onepage&q=yorn%20BOOL%20ios&f=false

NEW: 
See: David Trotz
http://stackoverflow.com/questions/18971389/proper-use-of-icloud-fallback-stores

https://github.com/dtrotzjr/APManagedDocument
________________________

How to Use the App:
See the “Sequence of Operations” folder and the figure captions.
Run the app on two devices at once.
The main view provides a table view of available UIManagedDocuments.
On the first launch, and on every launch after removing all cloud documents, the table view is empty.
Otherwise, a metadata query populates the table with existing cloud documents.
The “+” button in the main view’s upper left adds a new document, initialized in the sandbox of the creating device, then made ubiquitous.
The app initializes each new document’s object graph programmatically, to identify its creating device.

Click the “+” button (main screen, upper left) on one device (the creating device).
A new document, "TestDoc1", appears in its table view.
The other device (the receiving device) will show that document rather quickly.
	• Each new document’s object graph includes:
        • a single TextEntry object, and 
        • a single (useless, neglected) ModelVersion object.
	• TextEntry has two useful properties: text (NSString) and modified (NSDate).
Then still on the creating device, touch the new document’s row in the table view.
A detail view appears as an inspector of the document.
It shows:
	• The document’s file name, e.g. “TestDoc1”, “TestDoc2”
	• The document’s state and the singleton TextEntry’s modified (NSDate) property.
		• Those first two text fields are immutable.
	• The single TextEntry’s text property appears in the text view below. It’s editable.
		• TextEntry.text is initialized on the creating device and shows the device’s name and model:

			-[DocumentsListController createTextEntry]
			<device name> (<device model>))

On the receiving device, the new document appears in the table view in perhaps 10 seconds, but initially its object graph is unavailable.
After about 90 seconds, when the object graph becomes available, a notification updates the Master View, and the Detail view becomes available to the user. 
For a given document, after both devices show the (same) object graph, edit operations on one device appear on the other within about 10 seconds.

Note that this application is a very simple test of UIManagedDocument cloud-syncing.
Each document's object graph contains just one instance of TextEntry, and it persists for the life of the document.
The application does not test removing or adding more NSManagedObjects in its documents.

________________________

The app provides two switches in its preferences under the Settings app:

• Enable Ping
	• Enable pinging on just two devices.
        • Choose for example an iPhone named "A" and an iPad named "B".
		• This demo is NOT designed to demonstrate pinging on more than two devices.
        • For more than two devices, the cloud update notifications could grow without useful limit.
	• While these two devices inspect the same document, a change to the text on one device triggers an update on the other device.
	• To start the process, choose the same document on both devices.
        • Say, TestDoc1 created on the "A" device.
		• This document should show the same object graph in both detail views.
		• Neither text view should show “<nil>”.
			• That’s typical of the receiving device before its first update from the cloud.
	• Change the text on one of the devices (say, "B"):
		• Touch the text view, and use the keyboard to append, say, “START”:

			-[DocumentsListController createTextEntry]
			A (iPhone) START

		• Dismiss the keyboard to update the document’s object graph.
	• After about 10 seconds, the other device ("A") detects the update.
        • (Detail: It waits a short time in case a few updates come in a burst.)
		• Then it appends its own ping message programmatically:

            -[DocumentsListController createTextEntry]
            A (iPhone) START A pings

		• After about 10 seconds, the first device ("B") detects the update, and the process repeats.

            -[DocumentsListController createTextEntry]
			A (iPhone) START A pings B pings

	• Each device records latencies in NSUserDefaults.
	• The developer can extract the latencies: 
        • From the debugger command line:
            • set a breakpoint in the -ping: method
            • > po [self reportLatencies]
            • copy/paste to Numbers.app
        • From NSUserDefaults:
            • In the Organizer, download the app's sandbox directory to your desktop
            • e.g., “com.mycompany.multidocument 2013-09-26 18.45.21.466.xcappdata”
            • Use Finder’s “Show Package Contents” on *.xcappdata
            • Open AppData/Library/Preferences/com.mycompany.multidocument.plist
            • Choose the array named "TextEntry Latencies across Devices"
            • Get the array of NSNumbers.

• Copy Cloud Container on Segue
	• With this option enabled, the app copies the cloud container into the Sandbox “Documents” directory. 
		• Copy goes to “Documents/copyOfCloudContainer/”.
	• The copy occurs on the segue from master (table view) to detail view.
	• The copy operation can take several seconds on each segue. Keep it disabled unless you need it.
	• When reporting bugs to Apple, it’s helpful to submit a copy of the cloud container. 
		• Use the Organizer window to select your device and application. 
		• The panel below shows “Data files in Sandbox”.
		• Use the download tool to get, e.g., “com.mycompany.multidocument 2013-09-26 14.05.03.110.xcappdata”
		• Use Finder’s “Show Package Contents” on *.xcappdata.

• Attempt Error Recovery
    • With this option enabled, the application builds documents using the RobustDocument class.
    • Otherwise (and by default), it uses UIManagedDocument
    • It seems best for all participating devices to share the same value for this option, and not to change it after any documents have been created and made ubiquitous.

________________________


Overview of the Xcode Project:
The project has two main classes:
• DocumentsListController: builds and shows available UIManagedDocument instances in a table view
	DocumentsListController has categories:
	• +Resources provides several useful class methods 
	• +Making provides methods for making new documents.
    • +Querying provides methods for discovering documents in the cloud.
    • +ErrorRecovering provides methods useful when the "Attempt Error Recovery" option is enabled. (See RobustDocument below.)
• DetailViewController: inspector for any given item of DocumentsListController’s table view
	DetailViewController has a category:
	• +Pinging demonstrates the latency of cloud syncing. (See “Enable Ping” above.)

The RobustDocument class is a subclass of UIManagedDocument, and provides a rudimentary starting point for error recovery.
It’s not really necessary.
Its two methods could be added as a category to an existing subclass of UIManagedDocument.
RobustDocument uses UIBAlertView from Stav Ashuri: stavash/UIBAlertView

The project provides a few categories on Foundation classes for minor convenience.
• NSURL+NPAssisting normalizes URLs: “/private/var/mobile/blah” becomes “/var/mobile/blah”.
• UIDocument+NPExtending provides a document state as a string, e.g., @“ [Closed|Editing Disabled]”.

The project’s data model is very simple: just TextEntry and ModelVersion.


