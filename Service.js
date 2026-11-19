// ============================================================================
//  QTranslate - Servicio "Google" con endpoints actualizados (2026)
// ============================================================================

var DETECT_SAMPLE_LEN = 400;

function serviceHeader() {
    return new ServiceHeader(
        1,
        "Google",
        "Servicio gratuito de traduccion de Google." + Const.NL2 +
        "https://translate.google.com" + Const.NL2 +
        "Endpoints actualizados (clients5 / dict-chrome-ex + gtx fallback)." + Const.NL +
        "\u00a9 Google",
        Capability.TRANSLATE | Capability.DETECT_LANGUAGE | Capability.LISTEN);
}

function serviceHost(capability) {
    if (capability === Capability.LISTEN) {
        return "https://translate.google." + (Options.PreferredDomain || Options.GoogleDomain || "com");
    }
    return "https://clients5.google.com";
}

function serviceLink(text, fromLang, toLang) {
    var host = "https://translate.google." + (Options.PreferredDomain || Options.GoogleDomain || "com");
    var url = host + "/";
    if (text) {
        var from = isLanguage(fromLang) ? codeFromLanguage(fromLang) : "auto";
        var to = isLanguage(toLang) ? codeFromLanguage(toLang) : "auto";
        url += format("#{0}/{1}/{2}", from, to, encodeGetParam(text));
    }
    return url;
}

SupportedLanguages = [-1, "auto", "af", "az", "sq", "ar", "hy", "eu", "be", "bg", "ca",
    "zh-CN", "zh-TW", "hr", "cs", "da", "nl", "en", "et", "fi", "tl", "fr", "gl", "de",
    "el", "ht", "iw", "hi", "hu", "is", "id", "it", "ga", "ja", "ka", "ko", "lv", "lt",
    "mk", "ms", "mt", "no", "fa", "pl", "pt", "ro", "ru", "sr", "sk", "sl", "es", "sw",
    "sv", "th", "tr", "uk", "ur", "vi", "cy", "yi", "eo", "hmn", "la", "lo", "kk", "uz",
    "si", "tg", "te", "km", "mn", "kn", "ta", "mr", "bn", "tt"];

function normalizeLanguageCode(code) {
    if (!code) return code;
    if (code === "he") return "iw";
    if (code === "zh") return "zh-CN";
    if (code === "zh-Hans") return "zh-CN";
    if (code === "zh-Hant") return "zh-TW";
    if (code === "in") return "id";
    if (code === "fil") return "tl";
    return code;
}

function buildTranslateRequest(text, fromCode, toCode) {
    var encoded = encodeUriParam(limitSource(prepareSource(text)));
    var path = format("/translate_a/t?client=dict-chrome-ex&sl={0}&tl={1}&ie=UTF-8&oe=UTF-8",
                      fromCode, toCode);
    if (path.length + 3 + encoded.length <= Const.MAX_URI_LEN) {
        return new RequestData(HttpMethod.GET, path + "&q=" + encoded);
    }
    return new RequestData(HttpMethod.POST, path, "q=" + encoded);
}

function extractResult(parsed) {
    var result = { text: "", code: "" };
    if (!parsed) return result;

    if (typeof parsed === "string") {
        result.text = parsed;
        return result;
    }
    if (!isArray(parsed)) return result;

    // Formato 1: Respuesta array directa de dict-chrome-ex [["texto traducido", "es"]] o ["texto"]
    for (var i = 0; i < parsed.length; i++) {
        var item = parsed[i];
        if (isArray(item)) {
            if (typeof item[0] === "string") {
                result.text += item[0];
            } else if (isArray(item[0])) {
                // Formato 2: Respuesta anidada tipo gtx [[["texto", "origen", ...]], null, "es"]
                for (var j = 0; j < item.length; j++) {
                    if (isArray(item[j]) && typeof item[j][0] === "string") {
                        result.text += item[j][0];
                    }
                }
            }
            if (!result.code && item.length > 1 && typeof item[1] === "string") {
                result.code = item[1];
            }
        } else if (typeof item === "string") {
            if (i === 0 || parsed.length === 1) {
                result.text += item;
            } else if (!result.code && item.length <= 8) {
                result.code = item;
            }
        }
    }
    return result;
}

function fixLineBreaks(text) {
    if (!text) return "";
    return text.replace(/\r\n/g, "\n").replace(/\n/g, Const.NL);
}

function serviceTranslateRequest(text, fromLang, toLang) {
    return buildTranslateRequest(text, codeFromLanguage(fromLang), codeFromLanguage(toLang));
}

function serviceTranslateResponse(request, responseBody, fromLang, toLang) {
    var result = extractResult(parseJSON(responseBody));
    var translation = fixLineBreaks(result.text);

    if (!isLanguage(fromLang) && result.code) {
        var detected = languageFromCode(normalizeLanguageCode(result.code));
        if (detected !== UNKNOWN_LANGUAGE) fromLang = detected;
    }

    return new ResponseData(translation, fromLang, toLang, "");
}

function serviceDetectLanguageRequest(text) {
    return buildTranslateRequest(limitSource(text, DETECT_SAMPLE_LEN), "auto", "en");
}

function serviceDetectLanguageResponse(responseBody) {
    var result = extractResult(parseJSON(responseBody));
    if (!result.code) return UNKNOWN_LANGUAGE;
    return languageFromCode(normalizeLanguageCode(result.code));
}

function serviceListenRequest(text, lang, slow) {
    var path = format("/translate_tts?ie=UTF-8&client=tw-ob&tl={0}&q={1}",
                      codeFromLanguage(lang), encodeGetParam(limitSource(text)));
    if (slow) path += "&ttsspeed=0.24";
    return new RequestData(HttpMethod.GET, path);
}
