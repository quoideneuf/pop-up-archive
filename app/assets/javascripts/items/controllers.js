angular.module('Directory.items.controllers', ['Directory.loader', 'Directory.user', 'Directory.items.models', 'Directory.entities.models', 'Directory.people.models', 'prxSearch', 'Directory.storage', 'ngRoute', 'ngSanitize'])
.controller('ItemsCtrl', [ '$scope', 'Item', 'Loader', 'Me', 'Storage', function ItemsCtrl($scope, Item, Loader, Me, Storage) {

  $scope.Storage = Storage;

  Me.authenticated(function (data) {
    if ($scope.collectionId) {
      $scope.items = Loader.page(Item.query(), 'Items');
    }
  });

  $scope.startUpload = function() {
    var newFiles = [];
    var newImages = [];
    $scope.$emit('filesAdded', newFiles);
  }

}])
.controller('ItemCtrl', ['$scope', '$timeout', '$q', '$modal', '$http', 'Item', 'Loader', 'Me', '$routeParams', 'Collection', 'Entity', '$location', 'SearchResults', 'Storage', '$window', function ItemCtrl($scope, $timeout, $q, $modal, $http, Item, Loader, Me, $routeParams, Collection, Entity, $location, SearchResults, Storage, $window) {

  $scope.Storage = Storage;

  $scope.storageModal = $modal({template: '/assets/items/storage.html', persist: false, show: false, backdrop: 'static', scope: $scope});

  if ($routeParams.id) {
    Loader.page(Item.get({collectionId:$routeParams.collectionId, id: $routeParams.id}), Collection.get({id:$routeParams.collectionId}), Collection.query(), 'Item-v2/'+$routeParams.id, $scope);
  }

  SearchResults.setCurrentIndex({id:$routeParams.id});
  $scope.nextItem = SearchResults.getItem(SearchResults.currentIndex + 1);
  $scope.previousItem = SearchResults.getItem(SearchResults.currentIndex - 1);
  $scope.searchResults = SearchResults;

  $scope.transcriptExpanded = false;

  $scope.updateImage = function() {
    if ($scope.item && $scope.item.imageFiles.length) {
      var images = $scope.item.imageFiles;
      var image = images[0];
      for (var i=1;i<images.length;i++) {
        if (images[i].id > image.id) {
          image = images[i];
        }
      }
      return image.file.file.thumb.url;
    } else if ($scope.collection && $scope.collection.imageFiles.length) {
      var images = $scope.collection.imageFiles;
      var image = images[0];
      for (var i=1;i<images.length;i++) {
        if (images[i].id > image.id) {
          image = images[i];
        }
      }
      return image.file.file.thumb.url;
    }
  };

  $scope.isFileProcessing = function(file) {
    var item = $scope.item;
    var user = $scope.currentUser;
    return (user && item && user.canEdit(item) && (file.transcript == null));
  };

  $scope.status = "uploading";
  $scope.upgradePlan = false;

  $scope.statusNotification = function(file) {
    $scope.taskStatus(file);
    var statusHTML = "<h4>Status: ";
    if ($scope.status == "uploading") {
      statusHTML += "uploading";
    } else if ($scope.status == "upload_failed") {
      statusHTML += "UPLOAD FAILED - please try uploading again or contact us if uploads keep failing.";
    } else if ($scope.status == "started" || $scope.status == "full") {
      statusHTML += "transcript processing.</h4>";
      if ($scope.upgradePlan) {
        statusHTML += "<p>The first two minutes of your transcription will be ready momentarily. <a href='/pricing'>Upgrade your plan for full transcripts.</a></p>";
      } else if ($scope.transcriptType == "Basic" && !$scope.upgradePlan) {
        statusHTML += "<p>The first two minutes of your transcription will be ready momentarily.";
      }
      statusHTML += "The full transcript will process in real time (a 30-minute file will take at least 30 minutes). We'll email you when it's ready.</p>";
    } else if ($scope.status == "ts_failed") {
      statusHTML += "TRANSCRIPTION FAILED - please <a href='mailto:edison@popuparchive.com?Subject=Transcription%20Failed%20-%20My%20User%20ID:%20"+ $scope.currentUser.id +"'>email us for support</a>";
    }
    return statusHTML;
  };

  $scope.taskStatus = function(file) {
    if (!file) { return false; }
    var upload, start, full;
    for (var i=0; i<file.tasks.length; i++) {
      var task = file.tasks[i];
      if (task.type == "upload") {
        upload = task.status;
      } else if (task.identifier == "ts_start") {
        start = task.status;
      } else if (task.identifier == "ts_all" || task.identifier == "ts_paid") {
        full = task.status;
      }
    }
    if (upload == "failed") {
      $scope.status = "upload_failed";
    } else if (start == "failed" || full == "failed"){
      $scope.status = "ts_failed";
    } else if (start == "working" || start == "created") {
      $scope.status = "started";
    } else if (full != "complete") {
      $scope.status = "full";
    } else if (full == "complete") {
      $scope.status = "finished";
    }
    if (!full) {
      $scope.upgradePlan = true;
    }
  };

  $scope.allowEditButton = function(file) {
    var item = $scope.item;
    var found = true;
    if (file.duration != null && file.duration <= 120 ) {
      var found = false;
    }
    else {
      if ($scope.status == "finished") {
          var found = false;
      }
    }
    return found;
  }

  $scope.toggleTranscript = function () {
    $scope.transcriptExpanded = !$scope.transcriptExpanded;
  };

  $scope.transcriptClass = function () {
    if ($scope.transcriptExpanded) {
      return "expanded";
    }
    return "collapsed";
  };

  // our version of angular-strap does not support prefixEvent (below)
  // so listen on 'modal-hide'
  // TODO change when we upgrade.
  $scope.$on('modal-hide', function() {
    //console.log('modal hidden');
    // re-enable buttons so can order for other audio on the page.
    jQuery('button.ts-upgrade').not('.disabled').prop('disabled', false);
  });

  $scope.getPremiumCostAndPromptOrder = function() {
    var audioFile = $scope.item.newAudioFile($scope.selectedAudioFile);
    var costUrl = audioFile.getPremiumCostUrl();
    $http.get(costUrl).success(function(data, headers, config) {
      //console.log('got cost: ', data);
      $scope.audioCost = data;
      $scope.audioFile = audioFile;
      $scope.orderPremiumTranscriptModal = $modal({template: '/assets/audio_files/order_premium_transcript.html', persist: true, show: true, backdrop: 'static', scope: $scope, prefixEvent: 'orderPremiumTranscriptModal'});
    }).
    error(function(data, status, headers, config) {
      console.log("ERROR!: ", data, status, headers);
    });
  };

  // register listener once. This event fired by credit card form.
  // if the user wants to order a premium transcript and they do not yet have
  // an active credit card, we intervene and ask for one.
  $scope.$on('userHasValidCreditCard', function(event, data) {
    //console.log('userHasValidCreditCard event fired', data);
    $scope.getPremiumCostAndPromptOrder();
  });

  // when premium transcript successfully ordered, disable its associated button.
  $scope.$on('premiumTranscriptOrdered', function(event, audioFile) {
    var btn = jQuery('#premium-ondemand-'+audioFile.id);
    //console.log("btn: ", btn);
    btn.html('Premium transcript ordered');
    btn.addClass('disabled'); // flag as permanently off
    btn.prop('disabled', true);
  });

  $scope.orderPremiumTranscript = function(af, $ev) {
    $scope.selectedAudioFile = af; // track so our listeners can get it.

    // disable all buttons immediately to prevent multiple clicks
    // modal listener (above) will re-enable
    jQuery('button.ts-upgrade').not('.disabled').prop('disabled', true);

    // if the user does not have an active credit card, ask for one.
    if (!$scope.currentUser.hasCreditCard()) {
      $scope.onDemandRequiresCC = true;
      $scope.orderPremiumCCModal = $modal({template: '/assets/account/credit_card.html', persist: true, show: true, backdrop: 'static', scope: $scope});
    }
    else {
      // credit card already on file, so
      // fire event that triggers the getPremiumCostAndPromptOrder immediately.
      $scope.$emit('userHasValidCreditCard');
    }

  };

  $scope.itemStorage = function() {
    $q.when($scope.storageModal).then( function (modalEl) {
      modalEl.modal('show');
    });
  };
  
  $scope.clearEntities = function() {
    $scope.item.entities.forEach(function(entity) {
      if (entity.isConfirmed === false) {
    	  $scope.deleteEntity(entity);
      }
    });
  };

  $scope.deleteEntity = function(entity) {
    var e = new Entity(entity);
    e.itemId = $scope.item.id;
    e.deleting = true;
    e.delete().then(function() {
      $scope.item.entities.splice($scope.item.entities.indexOf(entity), 1);
    });
  };

  $scope.confirmEntity = function(entity) {
    // console.log('confirmEntity', entity);
    entity.itemId = $scope.item.id;
    entity.isConfirmed = true;
    var entity = new Entity(entity);
    entity.update();
  };
    
  $scope.deleteItem = function () {
    if (confirm("Are you sure you want to delete the item " + $scope.item.title +"? \n\n This cannot be undone." )){
      $scope.item.delete().then(function () {
        $timeout(function(){ $scope.$broadcast('datasetChanged')}, 100);
        $location.path('/collections/' + $scope.collection.id);
      })
    }
  };
  
  $scope.encodeText = function (text) {
    return encodeURIComponent(text);
  };
  

  $scope.callEditor = function() {
    $scope.$broadcast('CallEditor');
    $scope.editTable = true;
  };

  $scope.callSave = function() {
    $scope.$broadcast('CallSave');
    $scope.editTable = false;
  }

// Update placeholder speaker names with contributor names
  $scope.assignSpeaker = function(contributor, speaker) {
    speaker.name = contributor.id.person.name;
    var speaker = new Speaker(speaker);
    speaker.update();
  }

  $scope.my_path= $window.location.protocol + "//" + $window.location.host;
}])
.controller('ItemStorageCtrl', [ '$scope', 'Item', 'Loader', 'Me', function ItemsCtrl($scope, Item, Loader, Me) {

  function pad(number) {
    if (number < 10) {
      return "0" + number;
    }
    return number;
  }

  $scope.durationString = function (secs) {
    var d = new Date(secs * 1000);

    return pad(d.getUTCHours()) + ":" + pad(d.getUTCMinutes()) + ":" + pad(d.getUTCSeconds());
  };
}])

.controller('ItemFormCtrl', ['$window', '$cookies', '$scope', '$http', '$q', '$timeout', '$route', '$routeParams', '$modal', 'Me', 'Loader', 'Alert', 'Collection', 'Item', 'Contribution', 'ImageFile', function FilesCtrl($window, $cookies, $scope, $http, $q, $timeout, $route, $routeParams, $modal, Me, Loader, Alert, Collection, Item, Contribution, ImageFile) {

  $scope.showFilesAlert = true;
  
  $scope.hideAlert = function() {
    $scope.showFilesAlert = false;
  };

  $scope.$watch('item', function (is) {
    if (!angular.isUndefined(is) && (is.id > 0) && angular.isUndefined(is.adoptToCollection)) {
      is.adoptToCollection = is.collectionId;
    }
  });

  $scope.selectedCollection = null;

  $scope.$watch('item.collectionId', function (cid) {
    $scope.setSelectedCollection();
  })

  $scope.$watch('item.adoptToCollection', function (cid) {
    $scope.setSelectedCollection();
  })

  $scope.setSelectedCollection = function () {
    if (angular.isUndefined($scope.item))
      return;

    var collectionId = $scope.item.adoptToCollection || $scope.item.collectionId;

    if (collectionId && (collectionId > 0) && (!$scope.selectedCollection || (collectionId != $scope.selectedCollection.id))) {
      for (var i=0; i < $scope.collections.length; i++) {
        if ($scope.collections[i].id == collectionId) {
          $scope.selectedCollection = $scope.collections[i];
          break;
        }
      }
    }
  };

  if ($scope.item && $scope.item.id) {
    $scope.item.adoptToCollection = $scope.item.collectionId;
  }

  $scope.submit = function () {
    // console.log('ItemFormCtrl submit: ', $scope.item);
    var saveItem = $scope.item;
    this.item = $scope.initializeItem(true);
    $scope.clear();

    var uploadFiles = saveItem.files;
    saveItem.files = [];
    var uploadImageFiles = saveItem.images;
    saveItem.images = [];

    var audioFiles = saveItem.audioFiles;
    var contributions = saveItem.contributions;

    Collection.get(saveItem.collectionId).then(function (collection) {
      if (angular.isArray(collection.items)) {
        collection.items.push(saveItem);
      }
    });

    if (saveItem.id) {

      saveItem.update().then(function (data) {
        // reset tags
        saveItem.tagList2Tags();
        $scope.addRemoteImageFile(saveItem, $scope.urlForImage);        
        $scope.uploadImageFiles(saveItem, uploadImageFiles);        
        $scope.uploadAudioFiles(saveItem, uploadFiles);
        $scope.updateAudioFiles(saveItem, audioFiles);
        $scope.updateContributions(saveItem, contributions);
        delete $scope.item;
        // console.log('scope after update', $scope);
        // $scope.item = saveItem;
        // if ($scope.item != $scope.$parent.item) {
        //   angular.copy($scope.item, $scope.$parent.item);
        // }
      });
    } else {
      saveItem.create().then(function (data) {
        // reset tags
        saveItem.tagList2Tags();
        $scope.addRemoteImageFile(saveItem, $scope.urlForImage);
        $scope.uploadImageFiles(saveItem, uploadImageFiles);
        $scope.uploadAudioFiles(saveItem, uploadFiles);
        $scope.updateAudioFiles(saveItem, audioFiles);
        $scope.updateContributions(saveItem, contributions);
        $timeout(function(){ $scope.$broadcast('datasetChanged')}, 750);
        delete $scope.item;
        // console.log('scope after create', $scope);
      });
    }

  };

  $scope.addRemoteImageFile = function (saveItem, imageUrl){
    if (!$scope.urlForImage)
      return;
    new ImageFile({remoteFileUrl: imageUrl, container: "items", containerId: saveItem.id} ).create();      
    $scope.item.images.push({ name: 'name', remoteFileUrl: imageUrl, size: ''});
    //console.log("url link", $scope.urlForImage);
    $scope.urlForImage = "";
  };



  $scope.clear = function() {
    $scope.hideUploadModal();
  }

  // used by the upload-button callback when new files are selected
  $scope.setFiles = function(event) {
    element = angular.element(event.target);

    $scope.$apply(function($scope) {

      var newFiles = element[0].files;

      // default title to first file if not already set
      if (!$scope.item.title || $scope.item.title == "") {
        $scope.item.title = newFiles[0].name;
      }

      // set default transcriptType based on subscriber plan
      // NOTE that we only want them to change the transcriptType
      // when user is directly uploading files.
      $scope.defaultTranscriptType = $scope.currentUser.hasPremiumTranscripts() ? "premium" : "basic";
      $scope.item.transcriptType = $scope.defaultTranscriptType;

      if (!$scope.item.files) {
        $scope.item.files = [];
      }

      // add files to the item
      angular.forEach(newFiles, function (file) {
        $scope.item.files.push(file);
      });

      element[0].value = "";

    });
  };

  $scope.setImageFiles = function(event) {
    element = angular.element(event.target);

    $scope.$apply(function($scope) {

      var newImageFiles = element[0].files;
      // console.log('image files',element[0].files);

      if (!$scope.item.images) {
        $scope.item.images = [];
      }

      // add image files to the item
      angular.forEach(newImageFiles, function (file) {
        $scope.item.images.push(file);
      });

      element[0].value = "";

    });
  };

  $scope.removeAudioFile = function(file) {
    if (file.id && (file.id > 0)) {
      file._delete = true;
    } else {
      $scope.item.files.splice($scope.item.files.indexOf(file), 1);
    }
  }

  $scope.removeImageFile = function(imageFile) {
    if (imageFile.id && (imageFile.id > 0)) {
      imageFile._delete = true;
    } else {
      $scope.item.images.splice($scope.item.images.indexOf(imageFile), 1);
    }
  }

  $scope.addContribution = function () {
    var c = new Contribution();
    if (!$scope.item.contributions) {
      $scope.item.contributions = [];
    }
    $scope.item.contributions.push(c);
  }

  $scope.deleteContribution = function(contribution) {
    // mark it to delete later
    if (contribution.id && (contribution.id > 0)) {
      contribution._delete = true;
    } else {
      $scope.item.contributions.splice($scope.item.contributions.indexOf(contribution), 1);
    }
  }

  $scope.updateContributions = function(item, contributions) {
    item.contributions = contributions;
    item.updateContributions();
  };

  $scope.updateAudioFiles = function(item, audioFiles) {
    item.audioFiles = audioFiles;
    item.updateAudioFiles();
  };

  $scope.tagSelect = function() {
    return {
      placeholder: 'Tags...',
      width: '284px',
      tags: [],
      initSelection: function (element, callback) { 
        callback($scope.item.getTagList());
      }
    }
  };

  $scope.languageSelect = function() {
    return {
      placeholder: 'Language...',
      width: '220px',
      data: Item.languages,
      initSelection: function (element, callback) { 
        callback(element.val());
      }
    }
  };  

  // the ajax version, maybe?
  // $scope.languageSelect = function() {
  //   return {
  //     placeholder: 'Language...',
  //     width: '220px',
  //     ajax: {
  //       url: '/languages.json',
  //       results: function (data) {
  //         return {results: data};
  //       }
  //     },
  //     initSelection: function (element, callback) { 
  //       callback($scope.item.language);
  //     }
  //   }
  // };  

  $scope.roleSelect = {
    placeholder:'Role...',
    width: '160px'
  };

  $scope.peopleSelect = {
    placeholder: 'Name...',
    width: '240px',
    minimumInputLength: 2,
    quietMillis: 100,
    formatSelection: function (person) { return person.name; },
    formatResult: function (result, container, query, escapeMarkup) { 
      var markup=[];
      $window.Select2.util.markMatch(result.name, query.term, markup, escapeMarkup);
      return markup.join("");
    },
    createSearchChoice: function (term, data) {
      if ($(data).filter(function() {
        return this.name.toUpperCase().localeCompare(term.toUpperCase()) === 0;
      }).length === 0) {
        return { id: 'new', name: term };
      }
    },
    initSelection: function (element, callback) {
      var scope = angular.element(element).scope();
      callback(scope.contribution.person);
    },
    ajax: {
      url: function (self, term, page, context) {
        return '/api/collections/' + ($routeParams.collectionId || $scope.item.collectionId) + '/people';
      },
      data: function (term, page) { return { q: term }; },
      results: function (data, page) { return { results: data }; }
    }
  }

}]);
