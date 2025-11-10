" Test word boundary patterns
echo "=== Word Boundary Test ==="

let test_cases = [
      \ 'dbo.E',
      \ 'FROM dbo.E',
      \ 'SELECT * FROM dbo.E',
      \ ]

for test_text in test_cases
  echo "Testing: '" . test_text . "'"

  " Pattern with word boundary
  if test_text =~# '\<\w\+\.\w\+$'
    echo "  MATCH: \\<\\w+\\.\\w+$ (word boundary)"
    echo "  Match: " . matchstr(test_text, '\<\w\+\.\w\+$')
  else
    echo "  NO MATCH: \\<\\w+\\.\\w+$ (word boundary)"
  endif

  " Pattern without word boundary
  if test_text =~# '\w\+\.\w\+$'
    echo "  MATCH: \\w+\\.\\w+$ (no boundary)"
    echo "  Match: " . matchstr(test_text, '\w\+\.\w\+$')
  else
    echo "  NO MATCH: \\w+\\.\\w+$ (no boundary)"
  endif

  echo ""
endfor
