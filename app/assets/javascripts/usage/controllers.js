angular.module('Directory.usage.controllers', ['Directory.usage.models'])
.controller('UsageCtrl', ['$scope', 'Me', '$modal', function ($scope, Me, $modal) {
  Me.authenticated(function (me) {
    $scope.me = me;
  });

}]);
