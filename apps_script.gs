const folderId = "google-drive-folder-id";

function deleteOldFiles() {
  var daysOld = 14;

  var cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - daysOld);

  var folder = DriveApp.getFolderById(folderId);
  var files = folder.getFiles();

  while (files.hasNext()) {
    var file = files.next();
    if (file.getLastUpdated() < cutoffDate) {
      file.setTrashed(true);
    }
  }
}

function doPost(e) {
  var EXPECTED_KEY = "your-shared-secret";
  
  try {
    var data = JSON.parse(e.postData.contents);
    if (data.secretKey !== EXPECTED_KEY) {
       var result = {
        status: 'error',
        message: 'Unauthenticated.'
      };
      return ContentService
        .createTextOutput(JSON.stringify(result))
        .setMimeType(ContentService.MimeType.JSON);
    }
    var camBase64Data = data.cam;
    var imageBase64Data = data.image;
    var fileName = data.filename;
    var mimeType = data.mimeType || 'application/octet-stream';

    var camDecodedData = Utilities.base64Decode(camBase64Data);
    var imageDecodedData = Utilities.base64Decode(imageBase64Data);
    
    var camBlob = Utilities.newBlob(camDecodedData, mimeType, fileName + "_HD");
    var imageBlob = Utilities.newBlob(imageDecodedData, mimeType, fileName);
    
    var folder = DriveApp.getFolderById(folderId);
    folder.createFile(camBlob);
    folder.createFile(imageBlob);
    
    var result = {
      status: 'success',
      message: 'File uploaded successfully'
    };
    
    return ContentService
      .createTextOutput(JSON.stringify(result))
      .setMimeType(ContentService.MimeType.JSON);
      
  } catch (error) {
    var result = {
      status: 'error',
      message: error.toString()
    };
    
    return ContentService
      .createTextOutput(JSON.stringify(result))
      .setMimeType(ContentService.MimeType.JSON);
  }
}