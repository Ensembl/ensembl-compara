# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


=head1 NAME

GO::CorbaServer::Configurable

=head1 SYNOPSIS

=head1 DESCRIPTION

Any configurable class should inherit from here

=head1 FEEDBACK

=head2 Mailing Lists


=head1 AUTHOR - Chris Mungall

Email: cjm@fruitfly.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


package GO::CorbaServer::Configurable;
use vars qw($AUTOLOAD @ISA);
use strict;


=head2 config

  Usage   - $corba_obj->config($config);
  Usage   - $config = $corba_obj->config();

=cut

sub config {
    my $self = shift;
    $self->{_config} = shift if @_;
    return $self->{_config};
}


=head2 _initialize

always make sure this is called from the subclass

=cut

sub _initialize {
    my $self = shift;
    my $paramh = shift;
    $self->config($paramh->{config});
}




1;

