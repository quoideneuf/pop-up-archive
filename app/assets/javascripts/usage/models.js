angular.module('Directory.usage.models', [])
.factory('Usage', '$http', '$location', '$q', ['Model', function (Model, $http, $location, $q) {
  var Usage = new Model({url:'/api/usage/{{period}}', name: 'usage'});

}]);
