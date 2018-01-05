=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink

=head1 DESCRIPTION

A linked pair of NamedClusterSet objects with extra stats + MNR algorithm

=cut

package Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument;  # import 'rearrange()'
use Bio::EnsEMBL::Compara::StableId::NamedClusterSet;
use Bio::EnsEMBL::Compara::StableId::Generator;
use Bio::EnsEMBL::Compara::StableId::Map;

# The $threshold parameter determines whether:
#   * the name is reused via simply the biggest subset of the from & to ($threshold=0, $matchtype='Majority'),
#   * or you also have to have a 'quorum' of, say, 67% ($threshold==0.67, $matchtype=='Major_67').
# The 'NextBest' matchtype of name reuse is only applied if $threshold==0.
#
#
#my $threshold = 0;    # switches off thresholding
my $threshold = 0.67;
#
my $maj_label =  $threshold ? sprintf("Major_%d", int($threshold*100) ) : 'Majority';
my @labels = ('Exact', 'Exact_o', $maj_label, $maj_label.'_o', 'NextBest', 'NextBest_o', 'NewName', 'NewName_o', 'NewFam', 'NewFam_o');


sub new {
    my $class = shift @_;

    my $self = bless { }, $class;

    my ($from, $to, $filename) =
         rearrange([qw(from to filename) ], @_);

    if($filename) {

        $self->load($filename);

    } elsif($from and $to) {

        $self->from($from);
        $self->to($to);

        $self->compute_stats();

    } else {
        die "Please define either -filename or (-from and -to) in the '$class' constructor";
    }

    return $self;
}

sub compute_stats {
    my $self       = shift @_;

    my $total_count  = 0;
    my $common_count = 0;

    foreach my $from_member (@{$self->from->get_all_members}) {
        my $from_clid = $self->from->mname2clid($from_member);
        if(my $to_clid = $self->to->mname2clid($from_member)) {
            $self->direct_contrib->{$from_clid}{$to_clid}++;
            $self->rev_contrib->{$to_clid}{$from_clid}++;
            $self->from_size->{$from_clid}++;
            $self->to_size->{$to_clid}++;
            $common_count++;
        } else { # disappeared members (disappearing either with or without the containing cluster)
            $self->xfrom_size->{$from_clid}++;
        }
        $total_count++;
    }
    foreach my $to_member (@{$self->to->get_all_members}) {
        my $to_clid = $self->to->mname2clid($to_member);
        if(!defined($self->from->mname2clid($to_member))) { # new members (going either into existing or new cluster)
            $self->xto_size->{$to_clid}++;
            $total_count++;
        }
    }

    warn "Total number of keys:  $total_count\n";
    warn "Number of common keys: $common_count\n";

        # "cleanup" procedure 1: forget the newborn members that do not make a new class, as they will not influence the MNR algorithm
    foreach my $to_clid (sort {$a <=> $b} keys %{$self->xto_size}) { # iterate through families that contain new members
        if($self->rev_contrib->{$to_clid}) {
            delete $self->xto_size->{$to_clid};
        }
    }
        # "cleanup" procedure 2: forget the disappearing members that did not make a separate class, as they will not influence the MNR algorithm either
    foreach my $from_clid (sort {$a <=> $b} keys %{$self->xfrom_size}) { # iterate through families that lost some members
        if($self->direct_contrib->{$from_clid}) {
            delete $self->xfrom_size->{$from_clid};
        }
    }
}

sub load {
    my $self     = shift @_;
    my $filename = shift @_;

    $self->from(Bio::EnsEMBL::Compara::StableId::NamedClusterSet->new());
    $self->to(  Bio::EnsEMBL::Compara::StableId::NamedClusterSet->new());

    open(LINKFILE, $filename) || die "Cannot open '$filename' file: $@";
    while (my ($from_clid, $from_clname, $from_size, $to_clid, $to_clname, $to_size, $contrib) = split(/\s/,<LINKFILE>)) {

        next unless($contrib=~/^\d+$/); # skip the header line if present

        if($from_size and $to_size) { # Shared
            $self->from->clid2clname($from_clid, $from_clname);
            $self->to->clid2clname($to_clid, $to_clname);

            $self->direct_contrib->{$from_clid}{$to_clid} = $contrib;
            $self->rev_contrib->{$to_clid}{$from_clid}    = $contrib;
            $self->from_size->{$from_clid}                = $from_size;
            $self->to_size->{$to_clid}                    = $to_size;
        } elsif($to_size) { # Newborn
            $self->to->clid2clname($to_clid, $to_clname);

            $self->xto_size->{$to_clid}                   = $to_size;
        } elsif($from_size) { # Disappearing
            $self->from->clid2clname($from_clid, $from_clname);

            $self->xfrom_size->{$from_clid}               = $from_size;
        }
    }
    close LINKFILE;
}

sub save {
    my $self     = shift @_;
    my $filename = shift @_;

    open(LINKFILE, ">$filename");

    foreach my $from_clid (sort {$a <=> $b} keys %{$self->direct_contrib}) {
        my $from_clname = $self->from->clid2clname($from_clid);
        my $subhash = $self->direct_contrib->{$from_clid};

        foreach my $to_clid (sort { $subhash->{$b} <=> $subhash->{$a} } keys %$subhash) {
            my $to_clname = $self->to->clid2clname($to_clid);
            my $cnt = $self->direct_contrib->{$from_clid}{$to_clid};

            print LINKFILE join("\t", $from_clid, $from_clname, $self->from_size->{$from_clid}, $to_clid, $to_clname, $self->to_size->{$to_clid}, $cnt)."\n";
        }
    }
    foreach my $to_clid (sort {$a <=> $b} keys %{$self->xto_size}) { # iterate through families that contain new members
        my $to_clname = $self->to->clid2clname($to_clid);

        print LINKFILE join("\t", 0, '-', 0, $to_clid, $to_clname, $self->xto_size->{$to_clid}, $self->xto_size->{$to_clid})."\n";
    }
    foreach my $from_clid (sort {$a <=> $b} keys %{$self->xfrom_size}) { # iterate through families that lost some members
        my $from_clname = $self->from->clid2clname($from_clid);

        print LINKFILE join("\t", $from_clid, $from_clname, $self->xfrom_size->{$from_clid}, 0, '-', 0, $self->xfrom_size->{$from_clid})."\n";
    }

    close LINKFILE;
}

# Sort new families by size (desc)
# Try to assign a name according to the biggest contributor in the new family (and "grab" it)
# If unsuccessful (has been "grabbed" earlier), count this attempt and take the next best candidate.
#
sub maximum_name_reuse {
    my ($self, $generator) = @_;

    $generator ||= Bio::EnsEMBL::Compara::StableId::Generator->new(-TYPE => $self->to->type, -RELEASE => $self->to->release, -MAP => $self->from );

    my $postmap   = Bio::EnsEMBL::Compara::StableId::Map->new(-TYPE => $self->to->type);

    my %from_taken        = (); # indicates the 'from' name has been taken 

    TOPAIR: foreach my $topair (sort { $b->[1] <=> $a->[1] } map { [$_,$self->to_size->{$_}] } keys %{$self->to_size} ) {
        my ($to_clid, $to_size) = @$topair;

        my $subhash = $self->rev_contrib->{$to_clid};

        my $td_counts  = 0;
        my $matchtype  = '';
        my $matchscore = 0;
        my $given_name = ''; # serves both as logical flag and the actual name

        FROMPAIR: foreach my $frompair (sort { $b->[1] <=> $a->[1] } map { [$_,$subhash->{$_}] } keys %$subhash ) {
            my ($from_clid, $contrib) = @$frompair;
            my $from_size = $self->from_size->{$from_clid};
            my $from_name = $self->from->clid2clname($from_clid);

            if(!defined $from_taken{$from_name}) { # means the '$from' name is still unused, so we can reuse it now

                if($contrib==$from_size and $contrib==$to_size) {
                    $matchtype  = 'Exact';
                } elsif($threshold>0) {  # either the majority rule is applicable or we don't bother looking at other possibilities (as they are even smaller)
                    if($contrib/$from_size>=$threshold and $contrib/$to_size>=$threshold) {
                        $matchtype  = $maj_label;
                    } # otherwise we have an implicit 'NewName' case
                } else { # non-threshold mode
                    $matchtype = $td_counts ? 'NextBest' : $maj_label;
                }

                if($matchtype) {
                    if($matchtype eq 'Exact') {
                        # $from_name =~ /^(\w+)(?:\.(\d+))?/;
                        # $given_name = $1.'.'. (defined($2) ? $2 : $generator->default_version() ); # same version (but we may want to make it more obvious)
                        $given_name = $from_name;
                    } else {
                        $from_name =~ /^(\w+)(?:\.(\d+))?/;
                        $given_name = $1.'.'. ((defined($2) ? $2 : $generator->default_version())+1); # change the version if the match is not exact (or set it if previously unset)
                    }
                    $from_taken{$from_name} = 1;
                    $matchscore = int(100*$contrib/$to_size);
                }
                last FROMPAIR;

            } # if name not taken

            $td_counts++; # counts all attempts, not only the ones where the '$from' name was unused

        } # FROMPAIR

            # the following two lines work either if we arrive here from 'last FROMPAIR' after implicit 'NewName'
            # or by exhausting all FROMPAIRS (beacause they were all taken)
        $matchtype  ||= 'NewName';
        $given_name ||= $generator->generate_new_name();

        $postmap->clid2clname($to_clid, $given_name);
        $postmap->clid2score($to_clid, $matchscore);

        if($to_size == 1) { $matchtype .= '_o'; }
    } # TOPAIR

    foreach my $to_clid (sort {$a<=>$b} keys %{$self->xto_size}) {

        my $given_name = $generator->generate_new_name();
        $postmap->clid2clname($to_clid, $given_name);
        $postmap->clid2score($to_clid, 0);

#        my $matchtype = ($self->xto_size->{$to_clid} == 1) ? 'NewFam_o' : 'NewFam';
    }

    return $postmap;
}

    # simply captures cluster inclusion events both ways: SymMatch|Included|Contains
sub mnr_lite {
    my $self = shift @_;

    my %accu = ();  # accumulator is a HoHoL

    TOPAIR: foreach my $topair (sort { $b->[1] <=> $a->[1] } map { [$_,$self->to_size->{$_}] } keys %{$self->to_size} ) {
        my ($to_clid, $to_size) = @$topair;
        my $subhash = $self->rev_contrib->{$to_clid};

        FROMPAIR: foreach my $frompair (sort { $b->[1] <=> $a->[1] } map { [$_,$subhash->{$_}] } keys %$subhash ) {
            my ($from_clid, $contrib) = @$frompair;
            my $from_size = $self->from_size->{$from_clid};
            my $from_name = $self->from->clid2clname($from_clid);

            my $from_contrib = $contrib/$from_size;
            my $to_contrib   = $contrib/$to_size;

            if(my $matchtype = 
                ($to_contrib >= $threshold)
                    ? (($from_contrib >= $threshold)
                        ? 'SymMatch'
                        : 'Included')
                    : (($from_contrib >= $threshold)
                        ? 'Contains'
                        : '')
            ) {
                push @{$accu{$to_clid}{$matchtype}}, $from_name;
            }
        } # FROMPAIR
    } # TOPAIR

    return \%accu;
}


# -------------------------------------getters and setters----------------------------------------

sub from {
    my $self = shift @_;

    if(@_) {
        $self->{'_from'} = shift @_;
    }
    return $self->{'_from'};
}

sub to {
    my $self = shift @_;

    if(@_) {
        $self->{'_to'} = shift @_;
    }
    return $self->{'_to'};
}

sub direct_contrib {
    my $self = shift @_;

    return ($self->{_direct_contrib} ||= {});
}

sub rev_contrib {
    my $self = shift @_;

    return ($self->{_rev_contrib} ||= {});
}

sub from_size {
    my $self = shift @_;

    return ($self->{_from_size} ||= {});
}

sub to_size {
    my $self = shift @_;

    return ($self->{_to_size} ||= {});
}

sub xfrom_size {
    my $self = shift @_;

    return ($self->{_xfrom_size} ||= {});
}

sub xto_size {
    my $self = shift @_;

    return ($self->{_xto_size} ||= {});
}

1;

