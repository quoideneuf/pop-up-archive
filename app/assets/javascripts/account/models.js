angular.module('Directory.account.models', [])
.factory('Plan', ['Model', function (Model) {
  var Plan = Model({url:'/api/plans', name: 'plan'});

  Plan.community = function () {
  	return this.get().then(function (plans) {
      var community;
      angular.forEach(plans, function (plan) {
        if (typeof community == 'undefined' && plan.id == "community") {
          community = plan;
        }
      });
      return community;
  	});
  };

  return Plan;

}])

.factory('SampleAudio', ['Model', '$rootScope', 'Player', function (Model, $rootScope, Player) {
  $rootScope.exampleAudioFile = {
    url:  "https://s3.amazonaws.com/puatestfiles/newscast.mp3",
    duration: "00:00:35"
  };

  $rootScope.play = function (file) {
    Player.play(file);
    $rootScope.fileUrl = file;
    console.log('tried to play');
  }

  $rootScope.pause = function () {
    Player.pause();
  }

  $rootScope.rewind = function () {
    Player.rewind();
  }

  $rootScope.isLoaded = function () {
    return Player.nowPlayingUrl() == $rootScope.fileUrl;
  }

  $rootScope.isPlaying = function () {
    return $rootScope.isLoaded() && !Player.paused();
  }

}])


.factory('Subscribe', ['Model', '$rootScope', 'Plan', '$window', '$modal', function (Model, $rootScope, Plan, $window, $modal) {
  $rootScope.interval = 'month';
  $rootScope.offer = $rootScope.offer || {};
  $rootScope.community = Plan.community();
  Plan.get().then(function(plans) {
    $rootScope.plans = [{id: "enterprise", name: "Enterprise", amount: "Lots of audio?", hours: "custom", interval: "month"}];
    plans.forEach(function(plan){
      switch(plan.id){
        case 'community':
        case '5_professional_mo':
        case '5_professional_yr':
        case '10_small_business_mo':
        case '10_small_business_yr':
          $rootScope.plans.push(plan);
      }
    });
  });

  $rootScope.longInterval = false;

  $rootScope.togglePlans = function () {
    $rootScope.interval = ( $rootScope.interval == 'year' ? 'month' : 'year');
    $rootScope.longInterval = !$rootScope.longInterval;
  };

  $rootScope.getInterval = function() {
    return $rootScope.interval;
  };

  $rootScope.isPremiumPlan = function (plan) {
    switch(plan.id){
      case '10_small_business_mo':
      case '10_small_business_yr':
      case 'enterprise':
        return true;
    }
  };

  $rootScope.isDisabled = function  (name) {
    if (name == "Small Business") {
      return true;
    }
  }

  $rootScope.changePlan = function (plan) {
    switch(plan.id){
      case 'enterprise':
        $modal({template: '/assets/plans/form.html', persist: true, show: true, backdrop: 'static'});
        return;
      default: 
        subscribe(plan);
    }
  };
}]);
