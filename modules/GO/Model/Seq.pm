# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Model::Seq;

=head1 NAME

  GO::Model::Seq;

=head1 SYNOPSIS

    print $gene_product->seq->seq;

=head1 DESCRIPTION

represents a biological sequence; uses the bioperl Bio::PrimarySeq class

any call that you can do on a bioperl sequence object, you can do
here, with the addition of the calls below

to get bioperl, see http://www.bioperl.org

=cut

use Carp;
use Exporter;
use Digest::MD5;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use Bio::PrimarySeq;
use strict;
use vars qw(@ISA $AUTOLOAD);

@ISA = qw(GO::Model::Root Exporter);

sub _valid_params {
    return qw(id xref_list pseq description);
}

sub _initialize 
{
    my $self = shift;
    my ($paramh) = @_;

    my @bpargs = @_;
    my %h = ();
    if (ref($paramh) eq "HASH") {
        @bpargs = ();
        foreach my $k (keys %$paramh) {
            if (grep {$k eq $_} $self->_valid_params) {
                $h{$k} = $paramh->{$k};
            }
            else {
                push(@bpargs, "-".$k, $paramh->{$k});
            }
        }
    }
    my $pseq = Bio::PrimarySeq->new(@bpargs);
    $self->pseq($pseq);
    $self->SUPER::_initialize(\%h);
}


=head2 pseq

  Usage   -
  Returns - Bio::PrimarySeq
  Args    -

=cut

sub pseq {
    my $self = shift;
    if (@_) {
        $self->{pseq} = shift;
        if ($self->{pseq}->isa("Bio::Seq::RichSeqI")) {
            my $annot = $self->{pseq}->annotation;
            foreach my $link ( $annot->each_DBLink ) {
                my $xref =
                  GO::Model::Xref->new;
                $xref->xref_key($link->primary_id);
                $xref->xref_dbname($link->database);
                $self->add_xref($xref);
            }
        }
    }
    return $self->{pseq};
}

sub id {
    my $self = shift;
    $self->{id} = shift if @_;
    return $self->{id};
}

sub residues {shift->pseq->seq(@_)}

=head2 md5checksum

  Usage   - my $md5 = $seq->md5checksum() OR $seq->md5checksum($md5)
  Returns - 32 char hex string
  Args    - 32 char hex string [optional]

checksum for seq - easy way to check if it has been changed etc

(requires Digest::MD5 module from CPAN)

=cut

sub md5checksum {
    my $self = shift;

    # we want to be able to manipulte the checksum
    # even if the actual residues are not in memory at this time
    if (@_) {
	$self->{md5checksum} = shift;	
    }
    my $res = $self->pseq->seq();
    if (!$res) {
	return $self->{md5checksum};
    }
    my $md5 = Digest::MD5->new;
    $md5->add($self->residues);
    my $hex = $md5->hexdigest;

    $self->{md5checksum} = $hex;
      
    return $self->{md5checksum};
}

=head2 to_fasta

  Usage   -
  Returns -
  Args    -

=cut

sub to_fasta {
    my $self = shift;

    my $res = $self->seq;
    $res =~ s/(.{50})/$1\n/g;
    my $hdr = $self->description || $self->display_id;
#    my $hdr = $self->display_id;

    return 
      sprintf(">%s\n%s\n",
              $hdr,
              $res);
}

=head2 add_xref

  - Usage : $term->add_xref($xref);
  - Args  : GO::Term::Xref
  

=cut

sub add_xref {
    my $self = shift;

    if (@_) {
	my $xref = shift;
        $self->xref_list([]) unless $self->xref_list;
        $xref->isa("GO::Model::Xref") || confess("Not an Xref");
        push(@{$self->xref_list}, $xref);
    }
}

# delegate calls to Bio::Seq object
sub AUTOLOAD {
    
    my $self = shift || confess;
 
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    if ($name eq "DESTROY") {
	# we dont want to propagate this!!
	return;
    }

    if (!$self->pseq) { confess("assertion error") }
    
    if ($self->pseq->can($name)) {
	return $self->pseq->$name(@_);
    }
    if ($self->is_valid_param($name)) {
	
	$self->{$name} = shift if @_;
	return $self->{$name};
    }
    else {
	confess("can't do $name on $self");
    }
    
}

1;
