use Test;

class Test::Mock::Log {
    has @!log-entries;

    method log-method-call($name, $capture) {
        @!log-entries.push({ :$name, :$capture });
    }

    method called($name, :$times) {
        my @calls = @!log-entries.grep({ .<name> eq $name });
        if defined($times) {
            ok +@calls == $times, "called $name $times time{ $times != 1 && 's' }";
        }
        else {
            ok ?@calls, "called $name";
        }
    }

    method never-called($name) {
        my @calls = @!log-entries.grep({ .<name> eq $name });
        ok !@calls, "never called $name";
    }
};

module Test::Mock {
    sub mocked($type) is export {
        # Generate a subclass that logs each method call.
        my %already-seen = :new;
        my $mocker = ClassHOW.new;
        $mocker.^add_parent($type.WHAT);
        for $type, $type.^parents() -> $p {
            last if $p === Mu;
            for $p.^methods(:local) -> $m {
                unless %already-seen{$m.name} {
                    $mocker.^add_method($m.name, (method (|$c) {
                        $!log.log-method-call($m.name, $c);
                    }).clone);
                    %already-seen{$m.name} = True;
                }
            }
        }

        # Add log attribute and a method to access it.
        $mocker.^add_attribute(Attribute.new( name => '$!log', has_accessor => False ));
        $mocker.^add_method('!mock_log', method { $!log });

        # Return a mock object.
        my $mocked = $mocker.^compose();
        return $mocked.new(log => Test::Mock::Log.new());
    }

    sub check-mock($mock, *@checker) is export {
        .($mock!mock_log) for @checker;
    }
}
