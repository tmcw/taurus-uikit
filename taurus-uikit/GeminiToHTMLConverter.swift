//
//  GeminiToHTMLConverter.swift
//  taurus-uikit
//
//  Created by Tom MacWright on 2/5/21.
//

import Foundation
import Html

func geminiToHTML(page: Page) -> String {
    let nodes: [Html.Node] = page.document!.tree.children.map { (node) -> Html.Node in
        switch node.data {
        case Data.root:
            return Html.Node.br
        case Data.brk:
            return Html.Node.br
        case let .listItem(value):
            return Html.Node.ul(.li(.text(value)))
        case let .text(value):
            return Html.Node.p(.text(value))
        case let .heading(value, rank):
            switch rank {
            case 1:
                return Html.Node.h1(.text(value))
            case 2:
                return Html.Node.h2(.text(value))
            default:
                return Html.Node.h3(.text(value))
            }

        case let .quote(value):
            return Html.Node.blockquote(.text(value))
        case let .pre(value, _):
            return Html.Node.pre(.text(value))
        case let .webLink(value, url):
            return Html.Node.div(Html.Node.a(
                attributes: [.href(url.absoluteString)],
                .text(value)
            ))
        case let .link(value, url):
            return Html.Node.div(Html.Node.a(
                attributes: [.href(url.absoluteString)],
                .text(value)
            ))
        }
    }
    return Html.render(
        Html.Node.document(
            Html.Node.html(
                .head(
                    .meta(viewport: .width(.deviceWidth), .initialScale(1)),
                    .style(safe: """
body {
  font-family: -apple-system-ui-serif, ui-serif;
  background: #111;
  color: #999;
  padding: 10px;
}

div {
  padding: 5px 0;
}

p {
  line-height: 1.625;
}

blockquote {
  padding: 5px;
  font-style: italic;
}

pre {
  overflow-x: auto;
  font-family: -apple-system-mono;
}

h1, h2, h3 {
  color: #fff;
}

a {
  color: #0074bf;
}
"""
                    )
                ),
                .body(.fragment(nodes))
            )))
}
