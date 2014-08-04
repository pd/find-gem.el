(ert-deftest env-strategy ()
  "The contents of $GEM_PATH or $GEM_HOME could contain the proper gem path."
  (with-env "GEM_PATH" "/some/path:/another/path"
    (should (equal '("/some/path" "/another/path") (find-gem-strategy-env))))

  (with-env "GEM_HOME" "/some/path"
    (with-env "GEM_PATH" nil
      (should (equal '("/some/path") (find-gem-strategy-env))))

    ; favor $GEM_PATH
    (with-env "GEM_PATH" "/some/path:/another/path"
      (should (equal '("/some/path" "/another/path") (find-gem-strategy-env)))))

  (with-env "GEM_PATH" nil
    (with-env "GEM_HOME" nil
      (should (not (find-gem-strategy-env))))))

(ert-deftest gem-env-strategy ()
  "Shelling out to 'gem env gempath' to find our gem path."
  (mocker-let ((shell-command-to-string (command)
                                        ((:input '("gem env gempath") :output "/a/b:/c/d"))))
    (should (equal '("/a/b" "/c/d") (find-gem-strategy-gem-env)))))
