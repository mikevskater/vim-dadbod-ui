" Test pattern matching for context detection
echo "=== Pattern Matching Test ==="
echo ""

let test_cases = [
      \ 'dbo.',
      \ 'dbo.E',
      \ 'dbo.Employees',
      \ 'SELECT * FROM dbo.',
      \ 'SELECT * FROM dbo.E',
      \ 'SELECT * FROM dbo.Employees',
      \ ]

for test_text in test_cases
  echo "Testing: '" . test_text . "'"

  " Clean up whitespace
  let text = substitute(test_text, '\s\+', ' ', 'g')
  echo "  Cleaned: '" . text . "'"

  " Test patterns
  " Pattern 1: \w\+\.\s*$ (column: table.)
  if text =~# '\w\+\.\s*$'
    echo "  MATCH: Column pattern (table.)"
    let qualifier = matchstr(text, '\w\+\ze\.\s*$')
    echo "    Qualifier: '" . qualifier . "'"
  endif

  " Pattern 2: \<\w\+\.\w\+$ (table: schema.partial)
  if text =~# '\<\w\+\.\w\+$' && text !~# '\<\w\+\.\w\+\.\w\+$'
    echo "  MATCH: Table pattern (schema.partial)"
    let parts = split(matchstr(text, '\<\w\+\.\w\+$'), '\.')
    echo "    Parts: " . string(parts)
  endif

  " Pattern 3: \w\+\.\w\+\.\s*$ (column: schema.table.)
  if text =~# '\w\+\.\w\+\.\s*$'
    echo "  MATCH: Column pattern (schema.table.)"
    let parts = split(matchstr(text, '\w\+\.\w\+\ze\.\s*$'), '\.')
    echo "    Parts: " . string(parts)
  endif

  echo ""
endfor

echo "=== Test Complete ==="
