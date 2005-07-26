
=head1 NAME

Bio::Tools::Run::Search::ensembl_wublastx - Ensembl BLASTX searches

=head1 SYNOPSIS

  see Bio::Tools::Run::Search::EnsemblBlast
  see Bio::Tools::Run::Search::wublastx

=head1 DESCRIPTION

Multiple inheretance object combining
Bio::Tools::Run::Search::EnsemblBlast and
Bio::Tools::Run::Search::wublastx

=cut

# Let the code begin...
package Bio::Tools::Run::Search::ensembl_wublastx;
use strict;

use vars qw( @ISA );

use Bio::Tools::Run::Search::EnsemblBlast;
use Bio::Tools::Run::Search::wublastx;

@ISA = qw( Bio::Tools::Run::Search::EnsemblBlast 
           Bio::Tools::Run::Search::wublastx );

BEGIN{
}

# Nastyness to get round multiple inheretance problems.
sub program_name{return Bio::Tools::Run::Search::wublastx::program_name(@_)}
sub algorithm   {return Bio::Tools::Run::Search::wublastx::algorithm(@_)}
sub version     {return Bio::Tools::Run::Search::wublastx::version(@_)}
sub parameter_options{
  return Bio::Tools::Run::Search::wublastx::parameter_options(@_)
}

#----------------------------------------------------------------------
1;

