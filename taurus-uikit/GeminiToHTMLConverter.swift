//
//  GeminiToHTMLConverter.swift
//  taurus-uikit
//
//  Created by Tom MacWright on 2/5/21.
//

import Foundation
import Html

func geminiToHTML(page: Page) -> String {
    var html = ""

    let nodes: [Html.Node] = page.document!.tree.children.map { (node) -> Html.Node in
        switch node.data {
        case Data.root:
            return Html.Node.br;
        case Data.brk:
            return Html.Node.br;
        case let .listItem(value):
            return Html.Node.ul(.li(.text(value)))
        case let .text(value):
            return Html.Node.p(.text(value))
        case let .heading(value, rank):
            return Html.Node.h1(.text(value))
        case let .quote(value):
            return Html.Node.blockquote(.text(value))
        case let .pre(value, _):
            return Html.Node.pre(.text(value))
        case let .webLink(value, url):
            return Html.Node.a(.text(value))
        case let .link(value, url):
            return Html.Node.a(.text(value))
        }
    }
    return Html.render(Html.Node.document(Html.Node.html(.body(.fragment(nodes)))));
}
