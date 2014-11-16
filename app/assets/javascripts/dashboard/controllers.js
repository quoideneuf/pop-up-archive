angular.module('Directory.dashboard.controllers', ['Directory.loader', 'Directory.user', 'Directory.dashboard.models'])
.controller('DashboardCtrl', [ '$scope', 'Item', 'Loader', 'Me', '$timeout', 'Stats', function ItemsCtrl($scope, Item, Loader, Me, $timeout, Stats) {
  Me.authenticated(function (data) {
  });

  if (window.location.pathname == "/"){
    mixpanel.track(
      "Home Page"
    );
  };

  //tally total minutes in archive for display on homepage
  var minutes = function () {
    Stats.query().then(function (stats) {
      $scope.stats = Math.floor((stats.publicAudio + stats.privateAudio)/60);
      $scope.mytimeout = $timeout(minutes, 3000);
    });
  }; 
  minutes();

  //cancel minutes timeout on route change
 $scope.$on('$locationChangeStart', function() {
    $timeout.cancel($scope.mytimeout);
 });
  
  $scope.subscribe = function () {
    window.location = "/users/sign_up?plan_id=community";
    mixpanel.track(
      "Clicked Get Started"
    );
  }    
}])