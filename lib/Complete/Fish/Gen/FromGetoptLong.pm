package Complete::Fish::Gen::FromGetoptLong;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

#use Complete;
use Getopt::Long::Util qw(parse_getopt_long_opt_spec);
use String::ShellQuote;

our %SPEC;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(gen_fish_complete_from_getopt_long_spec);

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
            summary => 'Command name',
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

    my $cmdname = $args{cmdname};
    if (!$cmdname) {
        ($cmdname = $0) =~ s!.+/!!;
    }

    my @cmds;
    my $prefix = "complete -c ".shell_quote($cmdname);
    push @cmds, "$prefix -e"; # currently does not work (fish bug)
    for my $ospec (sort keys %$gospec) {
        my $res = parse_getopt_long_opt_spec($ospec)
            or die "Can't parse option spec '$ospec'";
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
                    $cmd .= " -r -f -a ".shell_quote("(begin; set -lx COMP_SHELL fish; set -lx COMP_LINE (commandline); set -lx COMP_POINT (commandline -C); ".shell_quote($cmdname)."; end)");
                }
                push @cmds, $cmd;
            }
        }
    }
    [200, "OK", join("", map {"$_\n"} @cmds)];
}

1;
# ABSTRACT:

=head1 SYNOPSIS


=head1 SEE ALSO

This module is used by L<Getopt::Long::Complete>.

L<Perinci::Sub::To::FishComplete>

