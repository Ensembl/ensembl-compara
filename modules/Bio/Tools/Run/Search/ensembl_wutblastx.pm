=head1 NAME

Bio::Tools::Run::Search::ensembl_wutblastx - Ensembl TBLASTX searches

=head1 SYNOPSIS

  see Bio::Tools::Run::Search::EnsemblBlast
  see Bio::Tools::Run::Search::wutblastx

=head1 DESCRIPTION

Multiple inheretance object combining
Bio::Tools::Run::Search::EnsemblBlast and
Bio::Tools::Run::Search::wutblastx

=cut

# Let the code begin...
package Bio::Tools::Run::Search::ensembl_wutblastx;
use strict;

use vars qw( @ISA );

use Bio::Tools::Run::Search::EnsemblBlast;
use Bio::Tools::Run::Search::wutblastx;

@ISA = qw( Bio::Tools::Run::Search::EnsemblBlast 
           Bio::Tools::Run::Search::wutblastx );

BEGIN{
}

# Nastyness to get round multiple inheretance problems.
sub program_name{return Bio::Tools::Run::Search::wutblastx::program_name(@_)}
sub algorithm   {return Bio::Tools::Run::Search::wutblastx::algorithm(@_)}
sub version     {return Bio::Tools::Run::Search::wutblastx::version(@_)}
sub parameter_options{
  return Bio::Tools::Run::Search::wutblastx::parameter_options(@_)
}

#----------------------------------------------------------------------
1;
