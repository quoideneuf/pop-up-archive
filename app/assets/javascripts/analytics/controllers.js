angular.module('Directory.analytics.controllers', ['Directory.loader', 'Directory.user', 'Directory.collections.models', 'Directory.analytics.models', 'ngTutorial', 'Directory.storage', 'Directory.analytics.directives'])
.controller('AnalyticsCtrl', ['$scope', '$location', 'Collection', 'AnalyticsData', 'Loader', 'Search', function ($scope, $location, Collection, AnalyticsData, Loader, Search) {

  $scope.$location = $location;
  $scope.facet = $location.search().query || 'tag';
  $scope.analyticsData = new AnalyticsData($scope.facet);

  Loader.page(Collection.get(), 'Collections', $scope).then(function (data) {
    $scope.collections = data;
    $scope.fetchCollections();
  });

  //Run search for all collections
  $scope.fetchCollections = function () {
    angular.forEach($scope.collections, function (collection) {
      $scope.fetchCollection(collection).then(function (data) {
        $scope.analyticsData.createCollection(collection, data);
      })
    })
  }

  $scope.fetchCollection = function (collection) {
    var searchParams = {
      'filters[collection_id]': collection.id
    }

    return Loader.page(Search.query(searchParams));
  }

  $scope.toggleCollection = function (collection) {
    if (collection.selected) {
      $scope.analyticsData.selectCollection(collection);
    } else {
      $scope.analyticsData.deselectCollection(collection);
    }
  }
}])
