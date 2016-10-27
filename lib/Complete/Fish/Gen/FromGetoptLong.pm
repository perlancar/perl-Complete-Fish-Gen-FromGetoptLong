package Complete::Fish::Gen::FromGetoptLong;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Getopt::Long::Util qw(parse_getopt_long_opt_spec);
use String::ShellQuote;

our %SPEC;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       gen_fish_complete_from_getopt_long_script
                       gen_fish_complete_from_getopt_long_spec
               );

$SPEC{gen_fish_complete_from_getopt_long_spec} = {
    v => 1.1,
    summary => 'From Getopt::Long spec, generate tab completion '.
        'commands for the fish shell',
    description => <<'_',


_
    args => {
        spec => {
            summary => 'Getopt::Long options specification',
            schema => 'hash*',
            req => 1,
            pos => 0,
        },
        cmdname => {
            summary => 'Command name to be completed',
            schema => 'str*',
            req => 1,
        },
        compname => {
            summary => 'Completer name, if there is a completer for option values',
            schema => 'str*',
        },
    },
    result => {
        schema => 'str*',
        summary => 'A script that can be fed to the fish shell',
    },
};
sub gen_fish_complete_from_getopt_long_spec {
    my %args = @_;

    my $gospec = $args{spec} or return [400, "Please specify 'spec'"];
    my $cmdname = $args{cmdname} or return [400, "Please specify cmdname"];
    my $compname = $args{compname};

    my @cmds;
    my $prefix = "complete -c ".shell_quote($cmdname);
    my $a_val  = shell_quote("(begin; set -lx COMP_SHELL fish; set -lx COMP_LINE (commandline); set -lx COMP_POINT (commandline -C); ".shell_quote($compname)."; end)")
        if $compname;
    push @cmds, "$prefix -e"; # currently does not work (fish bug?)
    for my $ospec (sort {
        # make sure <> is the last
        my $a_is_diamond = $a eq '<>' ? 1:0;
        my $b_is_diamond = $b eq '<>' ? 1:0;
        $a_is_diamond <=> $b_is_diamond || $a cmp $b
    } keys %$gospec) {
        my $res = parse_getopt_long_opt_spec($ospec)
            or die "Can't parse option spec '$ospec'";
        if ($res->{is_arg} && $compname) {
            push @cmds, "$prefix -a $a_val";
        } else {
            $res->{min_vals} //= $res->{type} ? 1 : 0;
            $res->{max_vals} //= $res->{type} || $res->{opttype} ? 1:0;
            for my $o0 (@{ $res->{opts} }) {
                my @o = $res->{is_neg} && length($o0) > 1 ?
                    ($o0, "no$o0", "no-$o0") : ($o0);
                for my $o (@o) {
                    my $cmd = $prefix;
                    $cmd .= length($o) > 1 ? " -l '$o'" : " -s '$o'";
                    # XXX where to get summary from?
                    if ($res->{min_vals} > 0) {
                        if ($compname) {
                            $cmd .= " -r -f -a $a_val";
                        } else {
                            $cmd .= " -r";
                        }
                    }
                    push @cmds, $cmd;
                }
            }
        }
    }
    [200, "OK", join("", map {"$_\n"} @cmds)];
}

$SPEC{gen_fish_complete_from_getopt_long_script} = {
    v => 1.1,
    summary => 'Generate fish completion script from Getopt::Long script',
    description => <<'_',


_
    args => {
        filename => {
            schema => 'filename*',
            req => 1,
            pos => 0,
            cmdline_aliases => {f=>{}},
        },
        cmdname => {
            summary => 'Command name to be completed, defaults to filename',
            schema => 'str*',
        },
        compname => {
            summary => 'Completer name',
            schema => 'str*',
        },
        skip_detect => {
            schema => ['bool', is=>1],
            cmdline_aliases => {D=>{}},
        },
    },
    result => {
        schema => 'str*',
        summary => 'A script that can be fed to the fish shell',
    },
};
sub gen_fish_complete_from_getopt_long_script {
    my %args = @_;

    my $filename = $args{filename};
    return [404, "No such file or not a file: $filename"] unless -f $filename;

    require Getopt::Long::Dump;
    my $dump_res = Getopt::Long::Dump::dump_getopt_long_script(
        filename => $filename,
        skip_detect => $args{skip_detect},
    );
    return $dump_res unless $dump_res->[0] == 200;

    my $cmdname = $args{cmdname};
    if (!$cmdname) {
        ($cmdname = $filename) =~ s!.+/!!;
    }
    my $compname = $args{compname};

    my $glspec = $dump_res->[2];

    # GL:Complete scripts can also complete arguments
    my $mod = $dump_res->[3]{'func.detect_res'}[3]{'func.module'} // '';
    if ($mod eq 'Getopt::Long::Complete') {
        $compname //= $cmdname;
        $glspec->{'<>'} = sub {};
    }

    gen_fish_complete_from_getopt_long_spec(
        spec => $dump_res->[2],
        cmdname => $cmdname,
        compname => $compname,
    );
}

1;
# ABSTRACT: Generate fish completion script from Getopt::Long spec/script

=head1 SYNOPSIS


=head1 SEE ALSO
