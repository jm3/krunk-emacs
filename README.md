##  Krunk: X/Emacs mode for editing & debugging JSP

**Copyleft July 2000, John Manoogian III ([@jm3](http://twitter.com/jm3))**

**Requires:**
[Lightning Completion](https://github.com/jhpalmieri/ultratex)

## Overview:
A JSP ([compiled server-side Java views](http://en.wikipedia.org/wiki/JavaServer_Pages) plus HTML + JS) 
editing mode, **Krunk** provides a power-editor's toolkit approach to JSP - no fluff, 
with quick access to common stuff. All of krunk's major commands are accessible from 
the Krunk menu -- click your 3rd mouse button to activate it.

## Features:
 * In-line JSP compilation
 * A `view-compiled-servlet` option when editing JSP source
 * Step forward/backward through page compilation errors
 * Completion of Java types, common HTML tags, and JSP primitives like `request.get...()`, `import declarations`, etc.
 * Popup menu for inserting code skeletons for pages, tables, and script blocks.

## Syntax highlighting (via font-lock) of:
 * Java types
 * JSP declarations
 * JSP expression tags
 * HTML tags (needs some work)
 * Java line comments
 * cvs/rcs $Id: ident strings

*Note that HTML attributes are NOT highlighted; that tends to make for a "confetti code" appearance, 
which I can do without.*
 
## Highlights:
 * Requires no server, no special Java `Classpath`-monkeying, databases, or other `JDK`s.

## History:
krunk began as a bastard child of several more complex modes, including `html-mode`, `perl-mode`, 
and whatever else looked promising. The first features were the font-locking regexps for syntax-coloring 
and lightning completion tables for tab completion. After using it daily for a few weeks, the tab-key 
binding proved to be too disorienting, and so was re-mapped to `ctl-c tab`.
