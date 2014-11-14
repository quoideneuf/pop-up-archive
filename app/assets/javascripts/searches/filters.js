angular.module("Directory.searches.filters", [])
.filter('queryPartHumanReadable', function() {
  return function (text) {

    var val = text;
    if (val.match(/(.+_id):\"(\d+)-(.*)\"/)) {
      val = val.replace(/(.+)_id:\"(\d+)-(.*)\"/,"\"$3\"");
    } else {
      val = val.replace(/\w+:/,'');
    }

    return val;
  }
})
.filter('highlightMatches', function() {
  var ary = [];
  return function (obj, matcher) {
    if (matcher && matcher.length) {
      var regex = new RegExp("(\\w*" + matcher + "\\w*)", 'ig');
      ary.length = 0;
      angular.forEach(obj, function (object) {
        if (object.text.match(regex)) {
          ary.push(object);
          // ary.push(angular.copy(object));
          // ary[ary.length-1].text = object.text.replace(regex, "<em>$1</em>");
        }
      });
      return ary;
    } else  {
      return obj;
    }
  }
})
.filter('characters', function () {
    return function (input, chars, breakOnWord) {
        if (isNaN(chars)) return input;
        if (chars <= 0) return '';
        if (input && input.length >= chars) {
            input = input.substring(0, chars);

            if (!breakOnWord) {
                var lastspace = input.lastIndexOf(' ');
                //get last space
                if (lastspace !== -1) {
                    input = input.substr(0, lastspace);
                }
            }else{
                while(input.charAt(input.length-1) == ' '){
                    input = input.substr(0, input.length -1);
                }
            }
            return input + '...';
        }
        return input;
    };
});