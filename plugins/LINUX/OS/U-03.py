from plugins import Plugin


class linuxosu03(Plugin):
	def __init__(self):
		super().__init__()
		self.code = "U-03"
		self.codeScript = """
linux003() {
	code=$1
	xml_infoElement_tag_start "$code"

	xml_fileInfo_write "/etc/pam.d/system-auth"
	xml_fileInfo_write "/etc/pam.d/password-auth"
	xml_fileInfo_write "/etc/pam.d/common-auth"
	xml_fileInfo_write "/etc/pam.d/common-account"

	xml_infoElement_tag_end "$code"
}
		"""
		self.codeExcute = "linux003 U-03"
		self.description = {
			'Category': '계정 관리',
			'Name': '계정 잠금 임계값 설정',
			'Important': '상',
			'ImportantScore': '3',
			'Criterion': '양호 : 계정 잠금 임계값이 5 이하의 값으로 설정되어 있는 경우\n'
			'취약 : 계정 잠금 임계값이 설정되어 있지 않거나, 5 이하의 값으로 설정되지 않은 경우',
			'ActionPlan': '계정 잠금 임계값을 5 이하로 설정'
		}
		self.fullString = [self.code, '양호', self.stat, self.description]

	def analysisFunc(self, sysInfo, infoDict, fileDict):
		chkFileList = ['/etc/pam.d/system-auth', '/etc/pam.d/password-auth', '/etc/pam.d/common-auth',
		               '/etc/pam.d/common-account']
		vulCnt = 0
		notfoundCnt = 0
		for file in chkFileList:
			#print(f'infoDict : {infoDict}')
			#print(f'file : {file}')
			chkFlag, dictKey = self.getFileName(infoDict, fileDict, file)
			#print(f'chkFlag : {chkFlag}')
			#print(f'dictKey : {dictKey}')
			if chkFlag:
				if self.getConfig(dictKey,
				                  '^auth\\s+(?:required|requisite)\\s+\\S*(?:pam_tally|pam_tally2|pam_faillock)\\.so.*$',
				                  'deny', 'exist'):
					vulCnt += self.compNumValue(dictKey, 'deny=([0-9]+)', 5, '<')
			else:
				notfoundCnt += 1

		if vulCnt == 0 or notfoundCnt == 4:
			self.fullString[1] = '취약'
		return self.fullString
