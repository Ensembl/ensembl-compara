# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


=head1 NAME

GO::CorbaServer::Base

=head1 SYNOPSIS



=head1 DESCRIPTION

Base class for all IDL interface implementations

=head1 FEEDBACK

=head2 Mailing Lists



=head1 AUTHOR - Chris Mungall

Email: cjm@fruitfly.org

Based on code by Ewan Birney:
Email: birney@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package GO::CorbaServer::Base;

use GO::CorbaServer::Configurable;
use GO::Structures qw(rearrange);
use vars qw($AUTOLOAD @ISA);
use strict;
@ISA = qw(GO::CorbaServer::Configurable);



sub new {
    my $class = shift;
    my $poa = shift;
    my $paramh = shift;
    my $self = {};
    bless $self,$class;

    $self->poa($poa);
    $self->reference_count(1);
    $self->_initialize($paramh);
    return $self;
}

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
}

sub ref {
    my $self = shift;

    $self->{'reference_count'}++;
}


sub unref {
    my $self = shift;
    if( $self->reference_count == 1 ) {
	$self->poa->deactivate_object ($self->poa->servant_to_id ($self));
    }
    $self->{'reference_count'}--;
}

=head2 poa

 Title   : poa
 Usage   : $obj->poa($newval)
 Function: 
 Example : 
 Returns : value of poa
 Args    : newvalue (optional)


=cut

sub poa{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'poa'} = $value;
    }
    return $obj->{'poa'};

}

=head2 reference_count

 Title   : reference_count
 Usage   : $obj->reference_count($newval)
 Function: 
 Example : 
 Returns : value of reference_count
 Args    : newvalue (optional)


=cut

sub reference_count {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'reference_count'} = $value;
    }
    return $obj->{'reference_count'};

}


=head2 log

  Usage   - $corba_obj->log(-code=>$code, -msg=>$message)
  Usage   - $corba_obj->log($message)
  Returns -
  Args    - code [int] 0 = low priority, 10 = high priority

=cut

sub log {
    my $self = shift;
    my ($msg, $code) = rearrange(['msg','code'], @_);
    my $fh = $self->config->serverlog_fh;
    printf $fh
      "%2d %s\n",
      $code || 0,
      $msg,
      ;
}


# ----- useful methods  --------


=head2 cvt_to_h

  Usage   - $obj->cvt_to_h($param_list)
  Returns - hashref
  Args    - ParamList struct

=cut

sub cvt_to_h {
    my $self = shift;
    my $param_list = shift;
    my $h = {};
    print "PARAMS=@$param_list\n";
    map {$h->{$_->{name}} = $_->{value}} @$param_list;
    return $h;
}

1;
