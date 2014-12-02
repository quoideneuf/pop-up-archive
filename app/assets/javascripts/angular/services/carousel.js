angular.module('Directory', ['ngAnimate'])
    .controller('MainCtrl', function ($scope) {
        $scope.slides = [
            {image: '#{asset_path('terkel.jpg')}', description: 'Image 00'},
            {image: '#{asset_path('pacifica.jpg')}', description: 'Image 01'},
            {image: '#{asset_path('WILL.jpg')}', description: 'Image 02'},
        ];
    });

    //have for loop go through images?

var carousel = angular.module("carousel", ['ngAnimate']);
carousel.controller("CarouselController", ["$scope", "$interval", function($scope, $interval) {
	$scope.slides = [
		{image: '#{asset_path('terkel.jpg')}', description: 'Image 00'},
		{image: '#{asset_path('pacifica.jpg')}', description: 'Image 01'},
		{image: '#{asset_path('WILL.jpg')}', description: 'Image 02'},
    ];

    $scope.currentImage = 0;

    $scope.nextImage = function() {
        if($scope.currentImage == $scope.slides.length - 1) {
            $scope.currentImage = 0;
        } else {
            $scope.currentImage += 1;
        }
    }

    $scope.previousImage = function() {
        if($scope.currentImage == 0) {
            $scope.currentImage = $scope.images.length - 1;
        } else {
            $scope.currentImage -= 1;
        }
    }

    $interval($scope.nextImage, 5000);
}]);

})()