=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::StableId::Map

=head1 SYNOPSIS

=head1 DESCRIPTION

    A smart container object that maintains clusterid-2-clustername and clusterid-2-mappingscore relationships,
    can load from file or save to file.

=cut

package Bio::EnsEMBL::Compara::StableId::Map;

use strict;
use Bio::EnsEMBL::Utils::Argument;  # import 'rearrange()'

sub new {
    my $class = shift @_;

    my $self = bless { }, $class;

    my ($type, $filename) =
         rearrange([qw(type filename) ], @_);

    $self->type($type)       if(defined($type));

    if($filename) {
        $self->load($filename);
    }

    return $self;
}

sub load {
    my $self     = shift @_;
    my $filename = shift @_;

    open(MAPFILE, $filename) || die "Could not open mapfile '$filename': $@";
    while(my $line=<MAPFILE>) {
        chomp $line;
            # support both formats during the switching period:
        my @syll = split(/\s+/, $line);
        my $clid   = shift @syll;
        my $score  = pop @syll;
        my $clname = pop @syll;

        $self->clid2clname($clid, $clname);
        $self->clid2score($clid,  $score);
    }
    close MAPFILE;
}

sub save {
    my $self     = shift @_;
    my $filename = shift @_;

    open(MAPFILE, ">$filename") || die "Could not open mapfile '$filename' for writing: $@";
    foreach my $clid (@{ $self->get_all_clids }) {
        print MAPFILE join("\t", $clid, $self->clid2clname($clid), $self->clid2score($clid))."\n";
    }
    close MAPFILE;
}

sub type {
    my $self = shift @_;

    if(@_) {
        $self->{'_type'} = shift @_;
    }
    return $self->{'_type'};
}

sub clid2clname {   # class_id -> class_name (1-to-1)
    my $self       = shift @_;
    my $clid  = shift @_;

    my $hash = $self->{'_clid2clname'} ||= {};

    if(@_) {
        $hash->{$clid} = shift @_;
    }
    return $hash->{$clid};
}

sub clid2score {   # class_id -> mapping score
    my $self       = shift @_;
    my $clid  = shift @_;

    my $hash = $self->{'_clid2score'} ||= {};

    if(@_) {
        $hash->{$clid} = shift @_;
    }
    return $hash->{$clid};
}

sub get_all_clids {
    my $self       = shift @_;

    return [ sort {$a<=>$b} keys %{ $self->{'_clid2clname'} ||= {} } ];
}

1;

