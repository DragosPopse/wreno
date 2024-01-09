## Features to develop and important bugs or fixes
- [ ] Make the parser accept utf8 only in strings, and ASCII as source code. Error when non-ASCII is used in non-strings source. This will make it on par with the wren c parser. 
- [ ] Implement AST
- [ ] Implement bytecode generation
- [ ] Implement interpreter
- [ ] Add character offset on line in the tokenizer. Useful for the language server