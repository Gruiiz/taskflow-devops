# Publicação no GitHub

O projeto está publicado no repositório público:

<https://github.com/Gruiiz/taskflow-devops>

Para obter uma cópia local:

```bash
git clone https://github.com/Gruiiz/taskflow-devops.git
cd taskflow-devops
```

Após cada atualização:

1. confirme a execução do workflow **Integração Contínua** na aba Actions;
2. opcionalmente proteja `main` e exija os jobs do CI antes do merge;
3. mantenha a URL pública do repositório no documento da disciplina;
4. não envie credenciais AWS, `terraform.tfvars`, `.terraform/` ou arquivos `*.tfstate`.

O job de infraestrutura apenas formata e valida o Terraform. Um `terraform apply` real deve
ser feito manualmente em uma conta de laboratório e seguido de `terraform destroy`.
