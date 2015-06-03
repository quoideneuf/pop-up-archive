// override some AngularStrap templates

angular.module('mgcrea.ngStrap.dropdown').run([ '$templateCache', function($templateCache) {
    $templateCache.put('dropdown/dropdown.tpl.html', '<ul tabindex="-1" class="dropdown-menu" role="menu"><li role="presentation" ng-class="{divider: item.divider}" ng-repeat="item in content"><a tabindex="-1" href="{{item.href}}" target="{{item.target || \'\'}}" data-method="{{item.method || \'get\'}}">{{item.text}}</a></li></ul>');
} ]);
