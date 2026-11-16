import Foundation
@testable import Phew

/// Made once when the test bundle loads (its principal class), before any test: fixes the word list for every test.
@objc(PhewTestSetup) final class TestSetup: NSObject {
    override init() { super.init(); CommonWords.fix() }
}

/// The common words the tests meet, as this Mac's English and Italian word lists gave them on 17 November 2026 (R45).
/// Fixed here so the tests give the same numbers on a Mac with other lists, or none. Made-up test sentences only.
enum CommonWords {
    static func fix() { NameMatch.fixedCommon = all }

    static let all: Set<String> = [
        "a", "about", "activity", "add", "affatto", "aggiungi", "al", "alice", "align", "am", "amigo", "an", "and",
        "andare", "apple", "apri", "as", "ask", "astra", "attiva", "available", "bakery", "bar", "barra", "birthday",
        "blu", "blue", "bold", "bozza", "breathe", "breathed", "bride", "brig", "bright", "brightness", "budget",
        "button", "call", "cambia", "can", "carattere", "catch", "cause", "caused", "cell", "cella", "center",
        "change", "changes", "che", "chiamare", "choose", "click", "color", "colore", "come", "con", "condividere",
        "condividi", "corsivo", "cosa", "ct", "cui", "da", "dalla", "dare", "del", "della", "detto", "di", "did",
        "dimensione", "do", "document", "documento", "does", "done", "down", "draft", "e", "elenco", "eleven",
        "error", "errore", "esporta", "ex", "explain", "export", "fa", "fact", "fantastico", "fat", "fatto", "fieno",
        "file", "files", "filing", "film", "finally", "finestra", "fisher", "font", "for", "format", "formato",
        "grass", "grassetto", "guarda", "guarderò", "gun", "ha", "he", "his", "ho", "how", "i", "il", "impostazione",
        "in", "inizia", "inserisci", "insert", "is", "it", "italic", "jazz", "just", "la", "laterale", "le",
        "leggendo", "line", "list", "made", "make", "manda", "mangio", "me", "meet", "menu", "metallic", "metti",
        "molto", "moss", "most", "mostra", "mostrami", "move", "nella", "new", "not", "nota", "note", "now", "nuovo",
        "oda", "of", "oil", "on", "online", "open", "orbit", "page", "pages", "pagina", "penso", "per", "perché",
        "plane", "post", "premi", "progetto", "project", "pulsante", "punta", "puntato", "quel", "questa", "questo",
        "quilt", "ran", "reading", "record", "remind", "rendi", "request", "revision", "revisioni", "ricordami",
        "rimes", "said", "salvo", "save", "say", "scegli", "schizzo", "sci", "scratch", "send", "senza", "serve",
        "set", "setting", "share", "she", "show", "showing", "side", "sidebar", "size", "sotto", "sottolinea",
        "sottolineato", "spa", "space", "spell", "spiegami", "spiga", "sposta", "spunta", "sta", "stack", "start",
        "sto", "stuffy", "su", "summarize", "sunrise", "t", "tabella", "table", "talk", "task", "tavolo", "testo",
        "text", "the", "this", "ticked", "title", "titolo", "to", "tomorrow", "track", "trailer", "turn", "un",
        "una", "under", "underline", "us", "van", "venerdì", "venne", "vet", "what", "why", "wild", "will", "window",
        "with", "you",
    ]
}
