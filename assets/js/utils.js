export function humanizeString(string) {
    string = string.replace(/[_-]/g, ' ');

    humanizedString = string.replace(/\b\w/g, function(match) {
      return match.toUpperCase();
    });

  return humanizedString
}
