#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Hive::Extensions

=cut

=head1 SYNOPSIS

unbound helper functions used in several places in the hive code, but
not bound to the objects they extend.

=cut

=head1 DESCRIPTION

=cut

=head1 CONTACT

Jessica Severin, jessica@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

use strict;

use Bio::EnsEMBL::Analysis;


sub Bio::EnsEMBL::Analysis::runnableDB
{
  my $self = shift;  #self is an Analysis object

  return undef unless($self);
  die("self must be a [Bio::EnsEMBL::Analysis] not a [$self]")
    unless($self->isa('Bio::EnsEMBL::Analysis'));

  return $self->{'runnableDB'} if($self->{'runnableDB'});

  my $runnable;
  if($self->module =~ "Bio::") { $runnable = $self->module; }
  else { $runnable = "Bio::EnsEMBL::Pipeline::RunnableDB::".$self->module; }
  (my $file = $runnable) =~ s/::/\//g;
  require "$file.pm";
  print STDERR "creating runnable ".$file."\n" if($self->{'verbose'});

  $runnable =~ s/\//::/g;
  my $runobj = "$runnable"->new(-db       => $self->adaptor->db,
                                -input_id => '1',
                                -analysis => $self,
                                );
  print STDERR "Instantiated ".$runnable." runnabledb\n" if($self->{'verbose'});

  $self->{'runnableDB'} = $runobj;
  return $self->{'runnableDB'};
}

1;

