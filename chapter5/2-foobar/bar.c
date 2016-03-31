void myprint(char *msg, int len);

int choose(int a, int b)
{
	if (a == 30)
	{
		myprint("a is 30\n", 9);
	}
	else
	{
		myprint("a is NOT 30\n", 13);
	}

	if (b == 30)
		myprint("b is 30\n", 9);
	else
		myprint("b is NOT 30 \n", 13);

	int i = 0;
	for (i = 0; i < a; i++)
		myprint("a", 1);
	myprint("test a end\n", 12);

	i = 0;
	for (i = 0; i < b; i++)
		myprint("b", 1);
	myprint("test b end\n", 12);
	return 0;
}
