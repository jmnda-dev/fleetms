export function humanizeString(string) {
    // Convert string to a more readable format (e.g., "camelCase" to "Camel Case")
    return string.replace(/([a-z])([A-Z])/g, '$1 $2').replace(/\b\w/g, c => c.toUpperCase());
}
